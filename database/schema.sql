-- Run as postgres on the database EC2 instance.
CREATE TABLE IF NOT EXISTS public.tasks (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.tasks OWNER TO shopbondhu_user;
