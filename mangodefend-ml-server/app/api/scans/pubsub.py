# app/api/scans/pubsub.py
import asyncio
from typing import List

class LogPubSub:
    """Pub/Sub manager for real-time scan event streaming."""
    def __init__(self):
        self.subscribers: List[asyncio.Queue] = []

    def subscribe(self) -> asyncio.Queue:
        q = asyncio.Queue()
        self.subscribers.append(q)
        return q

    def unsubscribe(self, q: asyncio.Queue):
        if q in self.subscribers:
            try:
                self.subscribers.remove(q)
            except ValueError:
                pass

    async def publish(self, data: dict):
        for q in self.subscribers:
            await q.put(data)

pubsub = LogPubSub()
