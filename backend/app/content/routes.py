from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..campaign import repository as campaign_repo
from ..common.audit_log import log_admin_action
from ..common.deps import CurrentUser, get_current_user, get_db, require_admin_user
from ..config import settings
from ..contributions.repository import award_approval_xp
# Reuses the teacher panel's text -> structured-MCQ extractor as-is — the
# task (paste freeform text, get back questions) is identical, only what
# happens to the result differs (admin: public draft bank row vs.
# teacher: private draft tied to one teacher).
from ..teacher.ai_import import extract_questions
from . import bulk_import, repository as repo
from .schemas import (
    AdminAiImportRequest,
    AdminAiImportResult,
    BulkImportRequest,
    BulkImportResult,
    CampaignStageCreate,
    CampaignStageOption,
    CampaignStageUpdate,
    CategoryCreate,
    CategoryOut,
    CategoryUpdate,
    QuestionCountOut,
    QuestionCreate,
    QuestionListItem,
    QuestionOut,
    QuestionUpdate,
    SeerahEventCreate,
    SeerahEventOut,
    SeerahEventUpdate,
    StageLinkRequest,
    StageLinkResult,
    StageReorderRequest,
)

# Admin-only: real admin/developer JWT, or legacy X-Admin-Key during migration.
router = APIRouter(prefix="/admin", tags=["content-admin"], dependencies=[Depends(require_admin_user)])

# Public (any authenticated user): active categories, for any player-facing
# feature that needs real category ids rather than the client's hardcoded
# practice-category slugs — currently just the contribution form.
public_router = APIRouter(tags=["content-public"])


@public_router.get("/categories", response_model=list[CategoryOut])
async def list_public_categories(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    return await repo.list_categories(db, active_only=True)


@router.post("/categories", response_model=CategoryOut, status_code=status.HTTP_201_CREATED)
async def create_category(
    data: CategoryCreate,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    try:
        result = await repo.create_category(db, data)
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"category slug '{data.slug}' already exists",
        )
    await log_admin_action(
        db, current.user_id, "category.create", target_type="category", target_id=str(result["id"])
    )
    return result


@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(db: AsyncSession = Depends(get_db)) -> list[dict]:
    return await repo.list_categories(db, active_only=False)


@router.patch("/categories/{category_id}", response_model=CategoryOut)
async def update_category(
    category_id: UUID,
    data: CategoryUpdate,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    result = await repo.update_category(db, category_id, data)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="category not found")
    await log_admin_action(
        db,
        current.user_id,
        "category.update",
        target_type="category",
        target_id=str(category_id),
        detail=data.model_dump(exclude_unset=True),
    )
    return result


@router.get("/seerah-events", response_model=list[SeerahEventOut])
async def list_seerah_events(db: AsyncSession = Depends(get_db)) -> list[dict]:
    """Feeds the admin question editor's event-tagging picker — see
    game/repository.py:pick_live_question for how a question's event_id
    determines which campaign stage(s) can serve it."""
    return await campaign_repo.list_events(db)


@router.post("/seerah-events", response_model=SeerahEventOut, status_code=status.HTTP_201_CREATED)
async def create_seerah_event(
    data: SeerahEventCreate,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    try:
        result = await campaign_repo.create_event(
            db, slug=data.slug, name=data.name, year_hijri=data.year_hijri, summary=data.summary
        )
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail=f"event slug '{data.slug}' already exists"
        )
    await log_admin_action(
        db, current.user_id, "event.create", target_type="seerah_event", target_id=str(result["id"])
    )
    return result


@router.patch("/seerah-events/{event_id}", response_model=SeerahEventOut)
async def update_seerah_event(
    event_id: UUID,
    data: SeerahEventUpdate,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    try:
        result = await campaign_repo.update_event(
            db,
            str(event_id),
            slug=data.slug,
            name=data.name,
            year_hijri=data.year_hijri,
            summary=data.summary,
        )
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail=f"event slug '{data.slug}' already exists"
        )
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="event not found")
    await log_admin_action(
        db,
        current.user_id,
        "event.update",
        target_type="seerah_event",
        target_id=str(event_id),
        detail=data.model_dump(exclude_unset=True),
    )
    return result


@router.delete("/seerah-events/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_seerah_event(
    event_id: UUID,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    try:
        deleted = await campaign_repo.delete_event(db, str(event_id))
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="event has questions tagged to it; retag or delete those questions first",
        )
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="event not found")
    await log_admin_action(
        db, current.user_id, "event.delete", target_type="seerah_event", target_id=str(event_id)
    )


@router.get("/campaign-stages", response_model=list[CampaignStageOption])
async def list_campaign_stages(db: AsyncSession = Depends(get_db)) -> list[dict]:
    """Feeds the admin question list's stage-link picker — see
    set_event_stage_tag below."""
    return await campaign_repo.list_stages(db)


@router.post("/campaign-stages", response_model=CampaignStageOption, status_code=status.HTTP_201_CREATED)
async def create_campaign_stage(
    data: CampaignStageCreate,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    try:
        result = await campaign_repo.create_stage(
            db, slug=data.slug, name=data.name, description=data.description
        )
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail=f"stage slug '{data.slug}' already exists"
        )
    await log_admin_action(
        db, current.user_id, "stage.create", target_type="campaign_stage", target_id=str(result["id"])
    )
    return result


@router.patch("/campaign-stages/{stage_id}", response_model=CampaignStageOption)
async def update_campaign_stage(
    stage_id: UUID,
    data: CampaignStageUpdate,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    try:
        result = await campaign_repo.update_stage(
            db, str(stage_id), slug=data.slug, name=data.name, description=data.description
        )
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail=f"stage slug '{data.slug}' already exists"
        )
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="stage not found")
    await log_admin_action(
        db,
        current.user_id,
        "stage.update",
        target_type="campaign_stage",
        target_id=str(stage_id),
        detail=data.model_dump(exclude_unset=True),
    )
    return result


@router.delete("/campaign-stages/{stage_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_campaign_stage(
    stage_id: UUID,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    stage = await campaign_repo.get_stage_by_id(db, str(stage_id))
    if stage is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="stage not found")
    linked = await campaign_repo.stage_linked_event_count(db, stage["slug"])
    if linked:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"{linked} event(s) are still linked to this stage; unlink them first",
        )
    try:
        deleted = await campaign_repo.delete_stage(db, str(stage_id))
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="stage has player progress or matches recorded and cannot be deleted",
        )
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="stage not found")
    await log_admin_action(
        db,
        current.user_id,
        "stage.delete",
        target_type="campaign_stage",
        target_id=str(stage_id),
        detail={"slug": stage["slug"]},
    )


@router.post("/campaign-stages/reorder", response_model=list[CampaignStageOption])
async def reorder_campaign_stages(
    data: StageReorderRequest,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    existing = await campaign_repo.list_stages(db)
    existing_ids = {str(s["id"]) for s in existing}
    requested_ids = [str(i) for i in data.stage_ids]
    if set(requested_ids) != existing_ids or len(requested_ids) != len(existing_ids):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="stage_ids must include every existing stage exactly once",
        )
    result = await campaign_repo.reorder_stages(db, requested_ids)
    await log_admin_action(
        db,
        current.user_id,
        "stage.reorder",
        target_type="campaign_stage",
        detail={"order": requested_ids},
    )
    return result


@router.put("/events/{event_id}/stage-tag", response_model=StageLinkResult)
async def set_event_stage_tag(
    event_id: UUID,
    data: StageLinkRequest,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Links (or, with stage_slug=None, unlinks) a Seerah event to a
    campaign stage. This is the one action that turns every question
    tagged to this event from 'orphaned' into 'linked' (or back) at once —
    see content/repository.py's _ORPHANED_EVENT_CHECK for how tag_status is
    derived from it."""
    if not await repo.event_exists(db, event_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="event not found")
    if data.stage_slug is not None and await campaign_repo.get_stage_id_by_slug(db, data.stage_slug) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="stage not found")
    await campaign_repo.set_event_stage_tag(db, event_id=str(event_id), stage_slug=data.stage_slug)
    await log_admin_action(
        db,
        current.user_id,
        "event.stage_tag",
        target_type="seerah_event",
        target_id=str(event_id),
        detail={"stage_slug": data.stage_slug},
    )
    return {"event_id": event_id, "stage_slug": data.stage_slug}


@router.get("/questions", response_model=list[QuestionListItem])
async def list_questions(
    category_id: UUID | None = None,
    review_state: str | None = None,
    search: str | None = None,
    tag_status: str | None = None,
    limit: int = 50,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    if review_state is not None and review_state not in ("draft", "reviewed", "live"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="review_state must be draft, reviewed, or live",
        )
    if tag_status is not None and tag_status not in ("untagged", "orphaned", "linked"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="tag_status must be untagged, orphaned, or linked",
        )
    return await repo.list_questions(
        db,
        category_id=category_id,
        review_state=review_state,
        search=search,
        tag_status=tag_status,
        limit=limit,
        offset=offset,
    )


@router.get("/questions/count", response_model=QuestionCountOut)
async def count_questions(
    category_id: UUID | None = None,
    review_state: str | None = None,
    search: str | None = None,
    tag_status: str | None = None,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Total matching rows for the current filters — lets the admin question
    list show 'showing N of TOTAL' and know when to offer another page,
    since list_questions itself is capped at `limit` rows per call.
    Registered ahead of /questions/{question_id} so 'count' is never parsed
    as a question id."""
    if review_state is not None and review_state not in ("draft", "reviewed", "live"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="review_state must be draft, reviewed, or live",
        )
    if tag_status is not None and tag_status not in ("untagged", "orphaned", "linked"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="tag_status must be untagged, orphaned, or linked",
        )
    count = await repo.count_questions(
        db,
        category_id=category_id,
        review_state=review_state,
        search=search,
        tag_status=tag_status,
    )
    return {"count": count}


@router.get("/questions/{question_id}", response_model=QuestionOut)
async def get_question(question_id: UUID, db: AsyncSession = Depends(get_db)) -> dict:
    result = await repo.get_question(db, question_id)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="question not found")
    return result


@router.patch("/questions/{question_id}", response_model=QuestionOut)
async def update_question(
    question_id: UUID,
    data: QuestionUpdate,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    if data.category_id is not None and not await repo.category_exists(db, data.category_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="category_id does not exist",
        )
    if data.event_id is not None and not await repo.event_exists(db, data.event_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="event_id does not exist",
        )
    result = await repo.update_question(db, question_id, data)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="question not found")
    await log_admin_action(
        db,
        current.user_id,
        "question.update",
        target_type="question",
        target_id=str(question_id),
        detail=data.model_dump(exclude_unset=True),
    )
    return result


@router.delete("/questions/{question_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_question(
    question_id: UUID,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    try:
        deleted = await repo.delete_question(db, question_id)
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="question has attempt/quiz history and cannot be deleted; "
            "set its review state back to 'draft' to hide it instead",
        )
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="question not found")
    await log_admin_action(
        db, current.user_id, "question.delete", target_type="question", target_id=str(question_id)
    )


@router.post("/questions", response_model=QuestionOut, status_code=status.HTTP_201_CREATED)
async def create_question(
    data: QuestionCreate,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    if not await repo.category_exists(db, data.category_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="category_id does not exist",
        )
    if data.event_id is not None and not await repo.event_exists(db, data.event_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="event_id does not exist",
        )
    result = await repo.create_question(db, data)
    await log_admin_action(
        db, current.user_id, "question.create", target_type="question", target_id=str(result["id"])
    )
    return result


@router.post("/questions/bulk-import", response_model=BulkImportResult)
async def bulk_import_questions(
    data: BulkImportRequest,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> BulkImportResult:
    try:
        raw_rows = (
            bulk_import.parse_json_rows(data.content)
            if data.format == "json"
            else bulk_import.parse_csv_rows(data.content)
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    result = await bulk_import.import_rows(db, raw_rows)
    await log_admin_action(
        db,
        current.user_id,
        "question.bulk_import",
        target_type="question",
        detail={"format": data.format, "created": result.created, "error_count": len(result.errors)},
    )
    return result


@router.post("/questions/ai-import", response_model=AdminAiImportResult)
async def ai_import_questions(
    data: AdminAiImportRequest,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> AdminAiImportResult:
    """Paste freeform text (a worksheet, Q&A pairs, plain notes) and an LLM
    extracts multiple-choice questions from it. Each one lands as a public
    'draft' bank row (unlike the teacher panel's private-per-teacher
    version) with its single-language text duplicated across en/ur/ar — a
    reviewer edits in the real translations (or accepts as-is) and promotes
    it through the normal draft -> reviewed -> live pipeline."""
    if not settings.openai_api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="AI import is not configured"
        )
    if not await repo.category_exists(db, data.category_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="category_id does not exist")
    if data.event_id is not None and not await repo.event_exists(db, data.event_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="event_id does not exist")
    try:
        extracted = await extract_questions(data.text)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))

    created = []
    for q in extracted:
        row = await repo.create_ai_question(
            db,
            category_id=data.category_id,
            prompt=q.prompt,
            options=q.options,
            correct_index=q.correct_index,
            event_id=data.event_id,
        )
        created.append({**row, "note": q.note})
    await log_admin_action(
        db,
        current.user_id,
        "question.ai_import",
        target_type="question",
        detail={"category_id": str(data.category_id), "created": len(created)},
    )
    return AdminAiImportResult(questions=created)


@router.post("/questions/{question_id}/review", response_model=QuestionOut)
async def review_question(
    question_id: UUID,
    state: str,
    current: CurrentUser = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Promote a question through the scholar-review workflow.
    state must be one of: draft, reviewed, live. Only 'live' questions are served."""
    if state not in ("draft", "reviewed", "live"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="state must be draft, reviewed, or live",
        )
    before = await repo.get_review_state_and_owner(db, question_id)
    result = await repo.set_review_state(db, question_id, state)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="question not found")
    if (
        state == "live"
        and before is not None
        and before["review_state"] != "live"
        and before["created_by"] is not None
    ):
        await award_approval_xp(db, str(before["created_by"]))
    await log_admin_action(
        db,
        current.user_id,
        "question.review",
        target_type="question",
        target_id=str(question_id),
        detail={"state": state},
    )
    return result