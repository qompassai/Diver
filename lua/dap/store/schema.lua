.lua
-- ~/.config/nvim/lua/dap/store/schema.lua
local M = {}

M.postgresql = [=[
CREATE TABLE IF NOT EXISTS dap_projects (
  id          TEXT PRIMARY KEY,
  root        TEXT NOT NULL UNIQUE,
  owner_name  TEXT NOT NULL DEFAULT current_user,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS dap_sessions (
  id              TEXT PRIMARY KEY,
  project_id      TEXT NOT NULL REFERENCES dap_projects(id) ON DELETE CASCADE,
  host_name       TEXT NOT NULL,
  adapter         TEXT NOT NULL,
  configuration   TEXT,
  request         TEXT,
  executable      TEXT,
  cwd             TEXT,
  git_commit      TEXT,
  git_branch      TEXT,
  metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
  owner_name      TEXT NOT NULL DEFAULT current_user,
  started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at        TIMESTAMPTZ,
  exit_code       INTEGER,
  result          TEXT
);

CREATE TABLE IF NOT EXISTS dap_events (
  id          BIGSERIAL PRIMARY KEY,
  session_id  TEXT NOT NULL REFERENCES dap_sessions(id) ON DELETE CASCADE,
  event_type  TEXT NOT NULL,
  payload     JSONB NOT NULL DEFAULT '{}'::jsonb,
  owner_name  TEXT NOT NULL DEFAULT current_user,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS dap_breakpoints (
  id             TEXT PRIMARY KEY,
  project_id     TEXT NOT NULL REFERENCES dap_projects(id) ON DELETE CASCADE,
  path           TEXT NOT NULL,
  line           INTEGER NOT NULL,
  column_number  INTEGER,
  condition      TEXT,
  hit_condition  TEXT,
  log_message    TEXT,
  enabled        BOOLEAN NOT NULL DEFAULT TRUE,
  owner_name     TEXT NOT NULL DEFAULT current_user,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(project_id, path, line, column_number)
);

CREATE TABLE IF NOT EXISTS dap_adapter_metrics (
  id            BIGSERIAL PRIMARY KEY,
  session_id    TEXT REFERENCES dap_sessions(id) ON DELETE CASCADE,
  adapter       TEXT NOT NULL,
  metric_name   TEXT NOT NULL,
  metric_value  DOUBLE PRECISION NOT NULL,
  unit          TEXT,
  metadata      JSONB NOT NULL DEFAULT '{}'::jsonb,
  owner_name    TEXT NOT NULL DEFAULT current_user,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS dap_sessions_project_started_idx
  ON dap_sessions(project_id, started_at DESC);

CREATE INDEX IF NOT EXISTS dap_sessions_adapter_started_idx
  ON dap_sessions(adapter, started_at DESC);

CREATE INDEX IF NOT EXISTS dap_events_session_created_idx
  ON dap_events(session_id, created_at);

CREATE INDEX IF NOT EXISTS dap_events_type_created_idx
  ON dap_events(event_type, created_at DESC);

CREATE INDEX IF NOT EXISTS dap_events_payload_gin_idx
  ON dap_events USING GIN(payload);

CREATE INDEX IF NOT EXISTS dap_breakpoints_project_path_idx
  ON dap_breakpoints(project_id, path);

CREATE INDEX IF NOT EXISTS dap_adapter_metrics_adapter_created_idx
  ON dap_adapter_metrics(adapter, created_at DESC);

ALTER TABLE dap_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE dap_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE dap_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE dap_breakpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE dap_adapter_metrics ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = current_schema()
      AND tablename = 'dap_projects'
      AND policyname = 'dap_projects_owner'
  ) THEN
    CREATE POLICY dap_projects_owner ON dap_projects
      USING (owner_name = current_user)
      WITH CHECK (owner_name = current_user);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = current_schema()
      AND tablename = 'dap_sessions'
      AND policyname = 'dap_sessions_owner'
  ) THEN
    CREATE POLICY dap_sessions_owner ON dap_sessions
      USING (owner_name = current_user)
      WITH CHECK (owner_name = current_user);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = current_schema()
      AND tablename = 'dap_events'
      AND policyname = 'dap_events_owner'
  ) THEN
    CREATE POLICY dap_events_owner ON dap_events
      USING (owner_name = current_user)
      WITH CHECK (owner_name = current_user);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = current_schema()
      AND tablename = 'dap_breakpoints'
      AND policyname = 'dap_breakpoints_owner'
  ) THEN
    CREATE POLICY dap_breakpoints_owner ON dap_breakpoints
      USING (owner_name = current_user)
      WITH CHECK (owner_name = current_user);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = current_schema()
      AND tablename = 'dap_adapter_metrics'
      AND policyname = 'dap_adapter_metrics_owner'
  ) THEN
    CREATE POLICY dap_adapter_metrics_owner ON dap_adapter_metrics
      USING (owner_name = current_user)
      WITH CHECK (owner_name = current_user);
  END IF;
END
$$;
]=]

M.sqlite = [=[
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

CREATE TABLE IF NOT EXISTS dap_projects (
  id          TEXT PRIMARY KEY,
  root        TEXT NOT NULL UNIQUE,
  owner_name  TEXT NOT NULL DEFAULT 'local',
  created_at  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dap_sessions (
  id              TEXT PRIMARY KEY,
  project_id      TEXT NOT NULL REFERENCES dap_projects(id) ON DELETE CASCADE,
  host_name       TEXT NOT NULL,
  adapter         TEXT NOT NULL,
  configuration   TEXT,
  request         TEXT,
  executable      TEXT,
  cwd             TEXT,
  git_commit      TEXT,
  git_branch      TEXT,
  metadata        TEXT NOT NULL DEFAULT '{}',
  owner_name      TEXT NOT NULL DEFAULT 'local',
  started_at      TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ended_at        TEXT,
  exit_code       INTEGER,
  result          TEXT
);

CREATE TABLE IF NOT EXISTS dap_events (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id  TEXT NOT NULL REFERENCES dap_sessions(id) ON DELETE CASCADE,
  event_type  TEXT NOT NULL,
  payload     TEXT NOT NULL DEFAULT '{}',
  owner_name  TEXT NOT NULL DEFAULT 'local',
  created_at  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dap_breakpoints (
  id             TEXT PRIMARY KEY,
  project_id     TEXT NOT NULL REFERENCES dap_projects(id) ON DELETE CASCADE,
  path           TEXT NOT NULL,
  line           INTEGER NOT NULL,
  column_number  INTEGER,
  condition      TEXT,
  hit_condition  TEXT,
  log_message    TEXT,
  enabled        INTEGER NOT NULL DEFAULT 1,
  owner_name     TEXT NOT NULL DEFAULT 'local',
  updated_at     TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(project_id, path, line, column_number)
);

CREATE TABLE IF NOT EXISTS dap_adapter_metrics (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id    TEXT REFERENCES dap_sessions(id) ON DELETE CASCADE,
  adapter       TEXT NOT NULL,
  metric_name   TEXT NOT NULL,
  metric_value  REAL NOT NULL,
  unit          TEXT,
  metadata      TEXT NOT NULL DEFAULT '{}',
  owner_name    TEXT NOT NULL DEFAULT 'local',
  created_at    TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS dap_sessions_project_started_idx
  ON dap_sessions(project_id, started_at DESC);

CREATE INDEX IF NOT EXISTS dap_sessions_adapter_started_idx
  ON dap_sessions(adapter, started_at DESC);

CREATE INDEX IF NOT EXISTS dap_events_session_created_idx
  ON dap_events(session_id, created_at);

CREATE INDEX IF NOT EXISTS dap_events_type_created_idx
  ON dap_events(event_type, created_at DESC);

CREATE INDEX IF NOT EXISTS dap_breakpoints_project_path_idx
  ON dap_breakpoints(project_id, path);

CREATE INDEX IF NOT EXISTS dap_adapter_metrics_adapter_created_idx
  ON dap_adapter_metrics(adapter, created_at DESC);
]=]

return M