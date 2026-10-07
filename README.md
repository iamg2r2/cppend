# C++ End Semester Practical Test

GitHub Pages + Supabase examination system for the Department of Computer Science.

## Current roster
- 26PCA101 through 26PCA162
- Discontinued/excluded: 26PCA104 and 26PCA155
- Active students: 60

## Student portal
`index.html`

Students enter their register number, receive two assigned questions, upload a code photograph and output photograph for each question, and can resume the same attempt.

## Teacher portal
`teacher.html`

The teacher portal is intentionally separate from the student portal. Open `/teacher.html` on GitHub Pages. The student page no longer contains a Teacher button.

Teacher password: `g2r2rocks`

The password is checked server-side against a bcrypt hash created by `supabase.sql`.

## Supabase setup
1. Open Supabase SQL Editor.
2. Run `supabase.sql`.
3. In `app.js` and `teacher.js`, replace `YOUR_SUPABASE_URL` and `YOUR_SUPABASE_ANON_KEY` with the project URL and public anon/publishable key.
4. Set the real examination date/time in `exam_settings`. The intended window is 9:00 AM–11:00 AM, Asia/Kolkata (+05:30).
5. Deploy `index.html`, `teacher.html`, `app.js`, `teacher.js`, and `styles.css` to GitHub Pages.

Do not put a Supabase service-role key in GitHub.

## Teacher controls
- View all 60 students
- View submitted code/output photographs
- Review proctor events
- Grade Mid, End, Viva and Record
- Download CSV
- Reset an individual student attempt

Reset deletes the attempt, uploaded photos, grades and proctor history so the student can start a fresh attempt.

## Testing
For a pre-exam test, temporarily set `exam_settings.exam_start` and `exam_settings.exam_end` to a short future window in Supabase, or use a dedicated test Supabase project. After testing, restore the real examination window.
