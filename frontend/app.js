const form = document.getElementById('task-form');
const input = document.getElementById('task-input');
const statusText = document.getElementById('status');
const list = document.getElementById('task-list');
const count = document.getElementById('task-count');
const empty = document.getElementById('empty');
const addButton = document.getElementById('add-button');

function showMessage(message, isError = false) {
  statusText.textContent = message;
  statusText.classList.toggle('error', isError);
}
async function api(path, options = {}) {
  const response = await fetch(path, { ...options, headers: { 'Content-Type': 'application/json', ...(options.headers || {}) } });
  if (response.status === 204) return null;
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
  return data;
}
function renderTasks(tasks) {
  list.replaceChildren();
  count.textContent = `${tasks.length} task${tasks.length === 1 ? '' : 's'}`;
  empty.hidden = tasks.length !== 0;
  for (const task of tasks) {
    const li = document.createElement('li');
    if (task.completed) li.classList.add('done');
    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.checked = task.completed;
    checkbox.setAttribute('aria-label', `Mark ${task.title} complete`);
    checkbox.addEventListener('change', async () => {
      try {
        await api(`/api/tasks/${task.id}`, { method: 'PATCH', body: JSON.stringify({ completed: checkbox.checked }) });
        await loadTasks();
      } catch (err) { showMessage(err.message, true); checkbox.checked = !checkbox.checked; }
    });
    const title = document.createElement('span');
    title.className = 'task-label';
    title.textContent = task.title; // Avoid inserting untrusted text as HTML.
    const remove = document.createElement('button');
    remove.className = 'remove';
    remove.type = 'button';
    remove.textContent = 'Delete';
    remove.addEventListener('click', async () => {
      try {
        await api(`/api/tasks/${task.id}`, { method: 'DELETE' });
        showMessage('Task deleted.');
        await loadTasks();
      } catch (err) { showMessage(err.message, true); }
    });
    li.append(checkbox, title, remove);
    list.append(li);
  }
}
async function loadTasks() {
  try {
    const data = await api('/api/tasks');
    renderTasks(data.tasks);
  } catch (err) {
    showMessage(`Could not load tasks: ${err.message}`, true);
  }
}
form.addEventListener('submit', async (event) => {
  event.preventDefault();
  const title = input.value.trim();
  if (!title) return;
  addButton.disabled = true;
  try {
    await api('/api/tasks', { method: 'POST', body: JSON.stringify({ title }) });
    input.value = '';
    showMessage('Task saved to PostgreSQL.');
    await loadTasks();
  } catch (err) { showMessage(`Could not save task: ${err.message}`, true); }
  finally { addButton.disabled = false; input.focus(); }
});
loadTasks();
