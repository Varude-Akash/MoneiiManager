-- Function used by Moneii AI edge function to execute AI-generated SELECT queries.
-- The caller (edge function) always wraps the query in CTEs that pre-filter by user_id
-- and date range before calling this function. This function acts as a second layer of
-- validation and executes the query returning results as a JSON array.

CREATE OR REPLACE FUNCTION public.run_ai_select(query_sql text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
AS $$
DECLARE
  result   jsonb;
  upper_sql text;
BEGIN
  upper_sql := upper(trim(query_sql));

  -- Must start with WITH (our CTE wrapper) or SELECT
  IF NOT (upper_sql LIKE 'WITH%' OR upper_sql LIKE 'SELECT%') THEN
    RAISE EXCEPTION 'run_ai_select: only SELECT/WITH queries are allowed';
  END IF;

  -- Block dangerous DML / DDL keywords
  IF upper_sql ~ '\y(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE|GRANT|REVOKE|EXECUTE|EXEC|COPY|VACUUM|IMPORT|LOAD)\y' THEN
    RAISE EXCEPTION 'run_ai_select: query contains disallowed keywords';
  END IF;

  -- Block multiple statements
  IF query_sql LIKE '%;%' THEN
    RAISE EXCEPTION 'run_ai_select: multiple statements are not allowed';
  END IF;

  EXECUTE format(
    'SELECT COALESCE(jsonb_agg(row_to_json(t)), ''[]''::jsonb) FROM (%s) t',
    query_sql
  ) INTO result;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.run_ai_select(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.run_ai_select(text) TO service_role;
