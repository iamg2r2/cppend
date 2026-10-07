const SUPABASE_URL='https://oxcseacsvqcbrlxuesui.supabase.co';
const SUPABASE_ANON_KEY='YOUR_SUPABASE_ANON_KEY';
const sb=supabase.createClient(SUPABASE_URL,SUPABASE_ANON_KEY);
let teacherToken=sessionStorage.getItem('cpp_teacher_token')||null;
let currentRows=[];
const $=id=>document.getElementById(id);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));
function show(el,on=true){if(el)el.classList.toggle('hidden',!on)}
function message(el,t){if(el)el.textContent=t||''}
async function teacherLogin(){
  const password=$('teacherPassword').value;
  message($('teacherMsg'),'');
  if(!password){message($('teacherMsg'),'Enter the teacher password.');return}
  const {data,error}=await sb.rpc('teacher_login',{p_password:password});
  if(error||!data?.ok){message($('teacherMsg'),error?.message||data?.message||'Invalid teacher password.');return}
  teacherToken=data.token;
  sessionStorage.setItem('cpp_teacher_token',teacherToken);
  show($('teacherLogin'),false); show($('dashboard'),true);
  await getRows();
}
async function getRows(){
  if(!teacherToken)return;
  const {data,error}=await sb.rpc('teacher_attempts',{p_token:teacherToken});
  if(error||!data?.ok){
    sessionStorage.removeItem('cpp_teacher_token'); teacherToken=null;
    show($('dashboard'),false); show($('teacherLogin'),true);
    message($('teacherMsg'),error?.message||data?.message||'Teacher session expired.');
    return;
  }
  currentRows=data.rows||[]; renderRows();
}
function filteredRows(){
  const q=$('studentSearch').value.trim().toUpperCase(),s=$('statusFilter').value,w=$('warningFilter').value;
  return currentRows.filter(r=>(!q||r.register_number.includes(q))&&(s==='all'||r.status===s)&&(w==='all'||(w==='flagged'?r.warning_count>0:r.warning_count===0)));
}
function renderRows(){
  const rows=filteredRows();
  $('totalCount').textContent=currentRows.length;
  $('submittedCount').textContent=currentRows.filter(r=>r.status==='submitted').length;
  $('inProgressCount').textContent=currentRows.filter(r=>r.status==='in_progress').length;
  $('flagCount').textContent=currentRows.reduce((n,r)=>n+Number(r.warning_count||0),0);
  $('gradeRows').innerHTML=rows.map(r=>{
    const attempted=!!r.attempt_id;
    return `<tr>
      <td><b>${esc(r.register_number)}</b></td>
      <td><span class="status-pill ${r.status==='submitted'?'status-submitted':r.status==='in_progress'?'status-progress':'status-none'}">${esc(r.status.replace('_',' '))}</span></td>
      <td>${attempted?(r.code1?'✓':'—')+' '+(r.output1?'· ✓':''): '—'}</td>
      <td>${attempted?(r.code2?'✓':'—')+' '+(r.output2?'· ✓':''): '—'}</td>
      <td class="${r.warning_count?'flag':''}">${r.warning_count||0}</td>
      <td>${attempted?`<input class="mark-input" id="m${r.attempt_id}" type="number" min="0" value="${r.mid}">`:'—'}</td>
      <td>${attempted?`<input class="mark-input" id="e${r.attempt_id}" type="number" min="0" value="${r.end_mark}">`:'—'}</td>
      <td>${attempted?`<input class="mark-input" id="v${r.attempt_id}" type="number" min="0" value="${r.viva}">`:'—'}</td>
      <td>${attempted?`<input class="mark-input" id="r${r.attempt_id}" type="number" min="0" value="${r.record}">`:'—'}</td>
      <td class="row-actions">${attempted?`<button class="view-btn" onclick="viewStudent('${r.attempt_id}')">View / Grade</button><button class="reset-btn" onclick="resetStudent('${r.attempt_id}')">Reset</button>`:'—'}</td>
    </tr>`;
  }).join('')||'<tr><td colspan="10">No students match the filter.</td></tr>';
}
async function grade(id){
  const r=currentRows.find(x=>x.attempt_id===id); if(!r)return;
  const vals=['m','e','v','r'].map(p=>Number($(p+id).value||0));
  const {data,error}=await sb.rpc('teacher_grade',{p_token:teacherToken,p_attempt_id:id,p_mid:vals[0],p_end:vals[1],p_viva:vals[2],p_record:vals[3]});
  if(error||!data?.ok){alert(error?.message||data?.message||'Could not save marks');return}
  Object.assign(r,{mid:vals[0],end_mark:vals[1],viva:vals[2],record:vals[3]});
  renderRows();
}
async function resetStudent(id){
  const r=currentRows.find(x=>x.attempt_id===id); if(!r)return;
  if(!confirm(`Reset the attempt for ${r.register_number}? This deletes their uploaded photos, answers and proctoring history so they can start again.`))return;
  const {data,error}=await sb.rpc('teacher_reset_attempt',{p_token:teacherToken,p_attempt_id:id});
  if(error||!data?.ok){alert(error?.message||data?.message||'Could not reset the student.');return}
  await getRows();
}
async function viewStudent(id){
  const r=currentRows.find(x=>x.attempt_id===id); if(!r)return;
  $('modalContent').innerHTML=`<p class="eyebrow">STUDENT SUBMISSION</p><h2>${esc(r.register_number)}</h2>
  <div class="submission-grid"><div><h4>Question 1 · ${esc(r.q1_title||'')}</h4>${r.code1?`<img src="${esc(r.code1)}" alt="Code image">`:'<div class="empty-photo">No code photo</div>'}</div><div><h4>Question 1 · Output</h4>${r.output1?`<img src="${esc(r.output1)}" alt="Output image">`:'<div class="empty-photo">No output photo</div>'}</div><div><h4>Question 2 · ${esc(r.q2_title||'')}</h4>${r.code2?`<img src="${esc(r.code2)}" alt="Code image">`:'<div class="empty-photo">No code photo</div>'}</div><div><h4>Question 2 · Output</h4>${r.output2?`<img src="${esc(r.output2)}" alt="Output image">`:'<div class="empty-photo">No output photo</div>'}</div></div>
  <div class="event-list"><h3>Proctor events (${r.warning_count||0})</h3>${(r.events||[]).map(e=>`<div class="event-row"><span>${esc(e.event_type.replaceAll('_',' '))}</span><span>${new Date(e.created_at).toLocaleTimeString()}</span></div>`).join('')||'<div class="event-row">No flagged events.</div>'}</div>
  <div class="marks-row"><label>Mid<input id="vmid" type="number" min="0" value="${r.mid}"></label><label>End<input id="vend" type="number" min="0" value="${r.end_mark}"></label><label>Viva<input id="vviva" type="number" min="0" value="${r.viva}"></label><label>Record<input id="vrecord" type="number" min="0" value="${r.record}"></label></div>
  <div class="modal-actions"><button class="secondary" onclick="resetStudent('${id}')">Reset Student</button><button class="primary" onclick="gradeFromModal('${id}')">Save Marks</button></div>`;
  show($('answerModal'),true);
}
async function gradeFromModal(id){
  const vals=[Number($('vmid').value||0),Number($('vend').value||0),Number($('vviva').value||0),Number($('vrecord').value||0)];
  const {data,error}=await sb.rpc('teacher_grade',{p_token:teacherToken,p_attempt_id:id,p_mid:vals[0],p_end:vals[1],p_viva:vals[2],p_record:vals[3]});
  if(error||!data?.ok){alert(error?.message||data?.message||'Could not save marks');return}
  const r=currentRows.find(x=>x.attempt_id===id); if(r)Object.assign(r,{mid:vals[0],end_mark:vals[1],viva:vals[2],record:vals[3]});
  show($('answerModal'),false); renderRows();
}
async function csv(){
  const {data,error}=await sb.rpc('teacher_csv',{p_token:teacherToken});
  if(error||!data?.ok){alert(error?.message||data?.message||'Could not create CSV');return}
  const blob=new Blob([data.csv],{type:'text/csv;charset=utf-8'}),a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='cpp_end_semester_marks.csv';a.click();URL.revokeObjectURL(a.href);
}
function logout(){sessionStorage.removeItem('cpp_teacher_token');teacherToken=null;show($('dashboard'),false);show($('teacherLogin'),true);message($('teacherMsg'),'');$('teacherPassword').value='';}
$('teacherLoginBtn').onclick=teacherLogin;
$('teacherPassword').addEventListener('keydown',e=>{if(e.key==='Enter')teacherLogin()});
$('refreshBtn').onclick=getRows; $('csvBtn').onclick=csv; $('logoutBtn').onclick=logout;
$('backBtn').onclick=()=>location.href='index.html'; $('closeModal').onclick=()=>show($('answerModal'),false);
$('studentSearch').oninput=renderRows; $('statusFilter').onchange=renderRows; $('warningFilter').onchange=renderRows;
window.viewStudent=viewStudent; window.gradeFromModal=gradeFromModal; window.resetStudent=resetStudent;
if(teacherToken){show($('teacherLogin'),false);show($('dashboard'),true);getRows();}
