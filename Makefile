.PHONY: up backend logs

up:
	docker-compose up --build

backend:
	python -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000

logs:
	tail -f backend/logs/*.log || true
