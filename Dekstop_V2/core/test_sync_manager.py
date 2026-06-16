import requests
import time

def test_socketio_server():
    import socketio
    sio = socketio.Client()
    try:
        sio.connect('http://localhost:8000')
        print('Connected to server')
        test_log = {'id': 1, 'message': 'Test log', 'synced': 0}
        sio.emit('upload_log', {'data': test_log})
        print('Test log sent')
        time.sleep(2)
        sio.disconnect()
        print('Disconnected')
    except Exception as e:
        print('Error:', e)

if __name__ == "__main__":
    test_socketio_server()
