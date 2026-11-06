"""ShopBondhu To-Do API. Application tier only; do not expose this port publicly."""
import logging
import os

import psycopg
from flask import Flask, jsonify, request
from psycopg.rows import dict_row

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)


def get_connection():
    """Open a fresh, short-lived PostgreSQL connection per request."""
    return psycopg.connect(
        host=os.environ.get("DB_HOST", "10.0.3.10"),
        port=int(os.environ.get("DB_PORT", "5432")),
        dbname=os.environ.get("DB_NAME", "shopbondhu_todo"),
        user=os.environ.get("DB_USER", "shopbondhu_user"),
        password=os.environ["DB_PASSWORD"],
        connect_timeout=5,
    )


def serialise_task(task):
    return {
        "id": task["id"],
        "title": task["title"],
        "completed": task["completed"],
        "created_at": task["created_at"].isoformat(),
    }


@app.get("/api/health")
def health():
    try:
        with get_connection() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
        return jsonify({"status": "ok", "database": "connected"})
    except (psycopg.Error, OSError):
        app.logger.exception("Database health check failed")
        return jsonify({"status": "unavailable"}), 503


@app.get("/api/tasks")
def get_tasks():
    try:
        with get_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
            cur.execute("SELECT id, title, completed, created_at FROM tasks ORDER BY id DESC LIMIT 100")
            result = [serialise_task(row) for row in cur.fetchall()]
        return jsonify({"tasks": result})
    except (psycopg.Error, OSError):
        app.logger.exception("Unable to list tasks")
        return jsonify({"error": "Database temporarily unavailable"}), 503


@app.post("/api/tasks")
def add_task():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify({"error": "Send a JSON object with a title"}), 400
    title = data.get("title")
    if not isinstance(title, str) or not (1 <= len(title.strip()) <= 150):
        return jsonify({"error": "Title must be 1-150 characters"}), 400
    try:
        with get_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                "INSERT INTO tasks (title) VALUES (%s) "
                "RETURNING id, title, completed, created_at",
                (title.strip(),),
            )
            task = serialise_task(cur.fetchone())
        return jsonify({"task": task}), 201
    except (psycopg.Error, OSError):
        app.logger.exception("Unable to add task")
        return jsonify({"error": "Database temporarily unavailable"}), 503


@app.patch("/api/tasks/<int:task_id>")
def update_task(task_id):
    data = request.get_json(silent=True)
    if not isinstance(data, dict) or type(data.get("completed")) is not bool:
        return jsonify({"error": "Send a boolean completed value"}), 400
    try:
        with get_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                "UPDATE tasks SET completed = %s WHERE id = %s "
                "RETURNING id, title, completed, created_at",
                (data["completed"], task_id),
            )
            row = cur.fetchone()
        if row is None:
            return jsonify({"error": "Task not found"}), 404
        return jsonify({"task": serialise_task(row)})
    except (psycopg.Error, OSError):
        app.logger.exception("Unable to update task")
        return jsonify({"error": "Database temporarily unavailable"}), 503


@app.delete("/api/tasks/<int:task_id>")
def delete_task(task_id):
    try:
        with get_connection() as conn, conn.cursor() as cur:
            cur.execute("DELETE FROM tasks WHERE id = %s RETURNING id", (task_id,))
            found = cur.fetchone() is not None
        if not found:
            return jsonify({"error": "Task not found"}), 404
        return "", 204
    except (psycopg.Error, OSError):
        app.logger.exception("Unable to delete task")
        return jsonify({"error": "Database temporarily unavailable"}), 503


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8000, debug=False)
