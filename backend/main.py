import os, time, base64
from collections import defaultdict
from flask import Flask, request, jsonify
from flask_cors import CORS
from groq import Groq

app = Flask(__name__)
CORS(app)

GROQ_API_KEY = os.environ.get('GROQ_API_KEY', '')
RATE_LIMIT   = int(os.environ.get('RATE_LIMIT', 5))
DAY_SEC      = 86400
MODEL        = 'meta-llama/llama-4-scout-17b-16e-instruct'

client = Groq(api_key=GROQ_API_KEY)

_store: dict[str, list[float]] = defaultdict(list)

def _remaining(device_id: str) -> int:
    now = time.time()
    _store[device_id] = [t for t in _store[device_id] if now - t < DAY_SEC]
    return max(0, RATE_LIMIT - len(_store[device_id]))

def _consume(device_id: str):
    _store[device_id].append(time.time())

def _call_groq(api_key: str, image_b64: str, question: str) -> str:
    c = Groq(api_key=api_key)
    response = c.chat.completions.create(
        model=MODEL,
        messages=[{
            'role': 'user',
            'content': [
                {'type': 'text', 'text': question},
                {'type': 'image_url', 'image_url': {'url': f'data:image/jpeg;base64,{image_b64}'}},
            ],
        }],
        max_tokens=1024,
    )
    return response.choices[0].message.content

@app.route('/health')
def health():
    return jsonify({'status': 'ok', 'model': MODEL})

@app.route('/analyze', methods=['POST'])
def analyze():
    data      = request.get_json(silent=True) or {}
    device_id = data.get('deviceId') or request.remote_addr or 'unknown'
    image_b64 = data.get('image')
    question  = data.get('question', 'What do you see? Describe in detail.')

    if not image_b64:
        return jsonify({'error': 'No image provided'}), 400

    remaining = _remaining(device_id)
    if remaining <= 0:
        return jsonify({
            'error': 'Daily free limit reached (5/day). Add your Groq API key in Settings for unlimited.',
            'limitReached': True,
            'remaining': 0,
        }), 429

    try:
        answer = _call_groq(GROQ_API_KEY, image_b64, question)
        _consume(device_id)
        return jsonify({'answer': answer, 'remaining': _remaining(device_id), 'byok': False})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/remaining')
def remaining():
    device_id = request.args.get('deviceId') or request.remote_addr
    return jsonify({'remaining': _remaining(device_id), 'limit': RATE_LIMIT})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 5000)))
