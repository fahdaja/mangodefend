import json
import logging
import pika
from typing import Dict, Any, Optional

from app.src.core.config import settings

logger = logging.getLogger("mangodefend.rabbitmq")

QUEUE_SCAN_EVENTS = "scan_events"
EXCHANGE_SCANS = "mangodefend.scans"


class RabbitMQPublisher:
    """Publisher client untuk mengirim event scan dan tugas latar belakang ke RabbitMQ."""

    def __init__(self, amqp_url: str = settings.RABBITMQ_URL):
        self.amqp_url = amqp_url

    def _get_connection(self) -> pika.BlockingConnection:
        """Membuat koneksi ke RabbitMQ server."""
        parameters = pika.URLParameters(self.amqp_url)
        parameters.socket_timeout = 5
        return pika.BlockingConnection(parameters)

    def publish_event(self, event_type: str, payload: Dict[str, Any]) -> bool:
        """
        Mengirimkan pesan JSON event scan ke RabbitMQ.
        Toleran terhadap kegagalan koneksi agar request API utama tidak down.
        """
        message = {
            "event_type": event_type,
            "data": payload
        }
        
        try:
            connection = self._get_connection()
            channel = connection.channel()

            # Deklarasi exchange dan queue
            channel.exchange_declare(
                exchange=EXCHANGE_SCANS,
                exchange_type="direct",
                durable=True
            )
            channel.queue_declare(queue=QUEUE_SCAN_EVENTS, durable=True)
            channel.queue_bind(
                exchange=EXCHANGE_SCANS,
                queue=QUEUE_SCAN_EVENTS,
                routing_key="scan.event"
            )

            channel.basic_publish(
                exchange=EXCHANGE_SCANS,
                routing_key="scan.event",
                body=json.dumps(message),
                properties=pika.BasicProperties(
                    delivery_mode=pika.DeliveryMode.Persistent,
                    content_type="application/json"
                )
            )
            connection.close()
            logger.info(f"[RabbitMQ] Published event '{event_type}' to queue '{QUEUE_SCAN_EVENTS}'")
            return True

        except Exception as e:
            logger.warning(f"[RabbitMQ] Could not publish message to RabbitMQ: {e}")
            return False


# Singleton instance publisher
rabbitmq_publisher = RabbitMQPublisher()
