from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import CurrentUser, get_current_user, get_db
from . import repository as repo
from .schemas import (
    ChallengeCreate,
    ChallengeOut,
    ChallengeScoreIn,
    FriendOut,
    FriendRequestByUserIn,
    FriendRequestCreate,
    FriendRequestOut,
    FriendRequestSentOut,
    MyCodeOut,
    RespondIn,
)

router = APIRouter(prefix="/social", tags=["social"])


@router.get("/me", response_model=MyCodeOut)
async def my_code(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    code = await repo.get_friend_code(db, current.user_id)
    if code is None:
        raise HTTPException(status_code=404, detail="user not found")
    return {"friend_code": code}


@router.post("/friends/requests", response_model=FriendRequestSentOut, status_code=status.HTTP_201_CREATED)
async def send_friend_request(
    data: FriendRequestCreate,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    target = await repo.find_user_by_code(db, data.friend_code)
    if target is None:
        raise HTTPException(status_code=404, detail="no user with that friend code")
    target_id = str(target["id"])
    if target_id == current.user_id:
        raise HTTPException(status_code=400, detail="you can't add yourself")
    existing = await repo.existing_relationship(db, current.user_id, target_id)
    if existing == "accepted":
        raise HTTPException(status_code=409, detail="already friends")
    if existing == "pending":
        raise HTTPException(status_code=409, detail="a request is already pending between you")
    row = await repo.create_friend_request(db, current.user_id, target_id)
    return {"id": row["id"], "to_display_name": target["display_name"], "status": row["status"]}


@router.post("/friends/requests/direct", response_model=FriendRequestSentOut, status_code=status.HTTP_201_CREATED)
async def send_friend_request_direct(
    data: FriendRequestByUserIn,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Add someone by user id rather than friend code — e.g. an opponent you
    just played a multiplayer match with. Still requires their acceptance,
    so this isn't a bigger trust bar than the code-based flow."""
    target_id = str(data.user_id)
    if target_id == current.user_id:
        raise HTTPException(status_code=400, detail="you can't add yourself")
    target = await repo.get_user_basic(db, target_id)
    if target is None:
        raise HTTPException(status_code=404, detail="user not found")
    existing = await repo.existing_relationship(db, current.user_id, target_id)
    if existing == "accepted":
        raise HTTPException(status_code=409, detail="already friends")
    if existing == "pending":
        raise HTTPException(status_code=409, detail="a request is already pending between you")
    row = await repo.create_friend_request(db, current.user_id, target_id)
    return {"id": row["id"], "to_display_name": target["display_name"], "status": row["status"]}


@router.get("/friends/requests", response_model=list[FriendRequestOut])
async def incoming_requests(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    return await repo.list_incoming_requests(db, current.user_id)


@router.post("/friends/requests/{request_id}/respond")
async def respond_to_request(
    request_id: str,
    data: RespondIn,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    row = await repo.respond_to_request(db, current.user_id, request_id, data.accept)
    if row is None:
        raise HTTPException(status_code=404, detail="request not found or already responded to")
    return {"status": row["status"]}


@router.get("/friends", response_model=list[FriendOut])
async def my_friends(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    return await repo.list_friends(db, current.user_id)


@router.delete("/friends/{friend_user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_friend(
    friend_user_id: str,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    await repo.unfriend(db, current.user_id, friend_user_id)


@router.post("/challenges", response_model=ChallengeOut, status_code=status.HTTP_201_CREATED)
async def create_challenge(
    data: ChallengeCreate,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    opponent_id = str(data.opponent_id)
    if not await repo.are_friends(db, current.user_id, opponent_id):
        raise HTTPException(status_code=403, detail="you can only challenge friends")
    created = await repo.create_challenge(db, current.user_id, opponent_id, data.category, data.question_count)
    detail = await repo.get_challenge_detail(db, str(created["id"]))
    assert detail is not None
    return detail


@router.get("/challenges", response_model=list[ChallengeOut])
async def my_challenges(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    return await repo.list_my_challenges(db, current.user_id)


@router.post("/challenges/{challenge_id}/score", response_model=ChallengeOut)
async def submit_score(
    challenge_id: str,
    data: ChallengeScoreIn,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    challenge = await repo.get_challenge(db, challenge_id)
    if challenge is None or current.user_id not in (str(challenge["challenger_id"]), str(challenge["opponent_id"])):
        raise HTTPException(status_code=404, detail="challenge not found")
    await repo.submit_challenge_score(db, challenge_id, current.user_id, data.correct_count)
    detail = await repo.get_challenge_detail(db, challenge_id)
    assert detail is not None
    return detail
