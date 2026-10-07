# C++ End Semester Practical Test

A GitHub Pages + Supabase web app for the Department of Computer Science C++ practical examination.

## Student experience
- Login with register number (`26PCA101`–`26PCA162`, excluding discontinued `26PCA104` and `26PCA155` (60 active students)).
- One persistent attempt per register number.
- One random Queue question + one random Constructor/Inheritance question.
- Exam window is fixed by Supabase (`09:00 AM`–`11:00 AM`).
- Students can leave and return; the same attempt resumes.
- Each question requires a photograph of the C++ code and a photograph of the output.
- Images are compressed in the browser and stored in Supabase Storage.
- No C++ code is executed in the browser.
- Tab/background/focus changes are recorded as proctor events. Multiple active browser sessions are flagged.
- At 11:00 AM the attempt is automatically submitted/locked.

## Teacher experience
- Separate Teacher view in the app.
- Password is checked server-side using a bcrypt hash.
- Dashboard lists all 60 students, including students who have not started.
- View code/output photographs and proctor events.
- Enter `mid`, `end`, `viva`, `record`.
- Download CSV with exactly: `reg number,mid,end,viva,record`.

## Supabase setup
1. Create a Supabase project.
2. Open **SQL Editor** and run `supabase.sql`.
3. IMPORTANT: the SQL contains a commented teacher-password setup line. Run it privately in the Supabase SQL editor:

```sql
insert into public.teachers(username,password_hash)
values('g2r2',crypt('g2r2rocks',gen_salt('bf')))
on conflict(username) do nothing;
```

Do **not** put that uncommented password line into a public GitHub repository.

4. In `app.js`, replace:

```js
const SUPABASE_URL='YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY='YOUR_SUPABASE_ANON_KEY';
```

with the project URL and anon/publishable key from Supabase Project Settings → API. Never put a service-role key in this project.

5. In `supabase.sql`, change the two `exam_start` / `exam_end` values to the actual examination date, using `+05:30` for India.

Example:

```sql
'2026-10-20 09:00:00+05:30', '2026-10-20 11:00:00+05:30'
```

6. Push `index.html`, `styles.css`, and `app.js` to GitHub Pages. `supabase.sql` should preferably remain private.

## Security note
Register-number-only login is not strong identity verification: a student who knows another register number could impersonate that student. The system prevents duplicate attempts at the database level, but stronger identity verification would require a PIN, QR code, institutional login, or invigilator verification.

Proctoring is audit-oriented rather than AI detection. A browser cannot reliably detect ChatGPT use on another phone, so the app records observable browser/session events and leaves academic judgment to the teacher.
