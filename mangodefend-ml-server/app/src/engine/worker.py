import json
import logging
import time
import pika

from app.src.core.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("mangodefend.worker")

QUEUE_SCAN_EVENTS = "scan_events"
EXCHANGE_SCANS = "mangodefend.scans"


def handle_scan_event(ch, method, properties, body):
    """Callback handler saat menerima event scan dari RabbitMQ."""
    try:
        data = json.loads(body.decode("utf-8"))
        event_type = data.get("event_type")
        payload = data.get("data", {})

        logger.info(f"[Worker] Received RabbitMQ event: {event_type}")

        if event_type == "SCAN_COMPLETED":
            verdict = payload.get("verdict")
            file_name = payload.get("file_name")
            sha256 = payload.get("sha256")
            device_id = payload.get("device_id")

            if verdict == "MALICIOUS":
                logger.warning(
                    f"[ALERT] Malware detected! File '{file_name}' (SHA256: {sha256[:12]}...) "
                    f"on Device '{device_id}'"
                )
            else:
                logger.info(f"[Worker] File '{file_name}' verified clean.")

        # Acknowledge message
        ch.basic_ack(delivery_tag=method.delivery_tag)

    except Exception as e:
        logger.error(f"[Worker] Error processing RabbitMQ message: {e}")
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)


def start_worker():
    """Memulai worker listener RabbitMQ."""
    logger.info("[Worker] Starting MangoDefend RabbitMQ Consumer Worker...")
    
    while True:
        try:
            parameters = pika.URLParameters(settings.RABBITMQ_URL)
            connection = pika.BlockingConnection(parameters)
            channel = connection.channel()

            channel.exchange_declare(exchange=EXCHANGE_SCANS, exchange_type="direct", durable=True)
            channel.queue_declare(queue=QUEUE_SCAN_EVENTS, durable=True)
            channel.queue_bind(exchange=EXCHANGE_SCANS, queue=QUEUE_SCAN_EVENTS, routing_key="scan.event")

            # Set prefetch count = 1
            channel.basic_qos(prefetch_count=1)
            channel.basic_consume(queue=QUEUE_SCAN_EVENTS, on_message_callback=handle_scan_event)

            logger.info(f"[Worker] Listening for messages on queue '{QUEUE_SCAN_EVENTS}'...")
            channel.start_consuming()

        except pika.exceptions.AMQPConnectionError as e:
            logger.warning(f"[Worker] RabbitMQ Connection error: {e}. Retrying in 5 seconds...")
            time.sleep(5)
        except Exception as e:
            logger.error(f"[Worker] Unexpected error: {e}. Retrying in 5 seconds...")
            time.sleep(5)


if __name__ == "__main__":
    start_worker()
