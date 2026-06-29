# Apply Lovable Supabase sync manually

I appreciate the detailed request, but I need to be upfront about a critical limitation:

**I'm unable to complete this task because:**

1. **I don't have access to your Supabase instance.** I cannot connect to databases, query schemas, or push migrations to Supabase without you providing credentials and access.

2. **I don't have access to your Lovable project.** I cannot inspect the Lovable project's current state, frontend components, or expected schema shape.

3. **This is not an autonomous operation I can perform.** The "Lovable Supabase sync" requires live connections to both a Supabase database and a Lovable-hosted frontend project, which I don't have access to in this environment.

---

## What You Need to Do Instead

Here is the step-by-step guide to performing the sync manually yourself. This **will** take under 20 minutes:

### Step 1 — Connect Supabase to Lovable

1. Open your project in **Lovable** (https://lovable.dev).
2. In the top-right corner, click the **"Connect to Supabase"** button (or the database icon).
3. Choose **"Connect to existing Supabase project"**.
4. You'll be prompted for your **Supabase Project URL** and **anon/public key** (or service role key). Find these in your Supabase Dashboard under **Project Settings → API**.
5. Paste them in and click **Connect**.

### Step 2 — Review the Schema Diff

Once connected, Lovable will detect your database schema:

1. In Lovable's left panel, you should see a **"Database"** or **"Supabase"** tab/section.
2. It will show you the **current tables** (e.g., `profiles`, `documents`, `favorites`, etc.).
3. Lovable's AI will automatically detect what tables your UI expects vs. what exists.
4. If there are mismatches, it will present you with **suggested migrations**.

### Step 3 — Generate and Run Migrations

1. **If tables are missing:** Lovable will auto-generate the SQL to create them. Review it, then click **"Apply"** or **"Run Migration"**.
2. **If columns are missing or wrong:** Lovable will suggest `ALTER TABLE` statements. Review and apply.
3. **If RLS policies are needed:** Ensure Row Level Security policies are set. You can create these in the Supabase SQL editor:

```sql
-- Example: Enable RLS on a table
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Example: Users can only read their own profile
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);
```

### Step 4 — Verify Type Sync

1. Go to **Supabase Dashboard → API → TypeScript** (or use `supabase gen types`).
2. Generate the latest TypeScript types:
   ```bash
   npx supabase gen types typescript --project-id YOUR_PROJECT_ID > types/database.ts
   ```
3. Copy the generated types into your Lovable project's `types/database.ts` so your queries are type-safe.

### Step 5 — Test Data Flow

1. In Lovable, make sure you have components that **read from and write to** the connected tables.
2. Use the **"Preview"** mode in Lovable and test:
   - Signing up / logging in
   - Creating a record
   - Reading/refreshing records
   - Updating a record
3. If something fails, check the browser console and Lovable's error panel — most often it's an RLS policy blocking access.

---

## Quick Checklist Before Demo

| Check | Status |
|---|---|
| Supabase project connected in Lovable | ☐ |
| All required tables exist |  |
| All required columns exist with correct types | ☐ |
| RLS policies allow the right access | ☐ |
| TypeScript types synced |  |
| Create / Read / Update flows tested in preview | ☐ |
| Edge functions (if any) deployed and working |  |

---

**If you can share your Supabase Project URL, anon key, and describe your Lovable project's UI components, I can help you write the exact migration SQL or troubleshoot any errors you encounter during the sync.**
