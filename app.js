const SUPABASE_URL='YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY='YOUR_SUPABASE_ANON_KEY';
const sb=supabase.createClient(SUPABASE_URL,SUPABASE_ANON_KEY);
const ATTEMPT_KEY='cpp_practical_attempt';
const SESSION_KEY='cpp_practical_session';
let attemptId=localStorage.getItem(ATTEMPT_KEY), sessionId=localStorage.getItem(SESSION_KEY)||crypto.randomUUID();
localStorage.setItem(SESSION_KEY,sessionId);
let currentAttempt=null,currentQuestion=1,currentRows=[];let saveTimer=null,heartbeatTimer=null,clockTimer=null,proctorBusy=false;
const $=id=>document.getElementById(id);const esc=s=>String(s??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
function show(el,on=true){el.classList.toggle('hidden',!on)}function message(el,t){el.textContent=t||''}
function formatLeft(sec){sec=Math.max(0,sec);return `${String(Math.floor(sec/3600)).padStart(2,'0')}:${String(Math.floor(sec%3600/60)).padStart(2,'0')}:${String(sec%60).padStart(2,'0')}`}
async function start(){const reg=$('regInput').value.trim().toUpperCase();message($('loginMsg'),'');if(!/^26PCA\d{3}$/.test(reg)){message($('loginMsg'),'Enter a valid register number, for example 26PCA142.');return}const {data,error}=await sb.rpc('start_or_resume_attempt',{p_register_number:reg,p_session_id:sessionId});if(error){message($('loginMsg'),error.message);return}if(!data?.ok){message($('loginMsg'),data?.message||'Unable to start the test.');return}attemptId=data.attempt_id;localStorage.setItem(ATTEMPT_KEY,attemptId);await loadAttempt()}
async function loadAttempt(){if(!attemptId)return false;const {data,error}=await sb.rpc('get_student_attempt',{p_attempt_id:attemptId,p_session_id:sessionId});if(error||!data?.ok){localStorage.removeItem(ATTEMPT_KEY);attemptId=null;return false}currentAttempt=data.attempt;show($('loginCard'),false);show($('examView'),true);$('studentReg').textContent=currentAttempt.register_number;updateExamWindow();startHeartbeat();return true}
function updateExamWindow(){
  const now=Date.now(),start=new Date(currentAttempt.exam_start).getTime(),end=new Date(currentAttempt.exam_end).getTime();
  const before=now<start, after=now>=end;
  show($('preExam'),before&&currentAttempt.status==='in_progress');
  show($('activeExam'),!before&&!after);
  if(before&&currentAttempt.status==='in_progress'){
    $('preExamText').textContent=`The C++ End Semester Practical Test will begin at ${new Date(start).toLocaleTimeString([], {hour:'numeric',minute:'2-digit'})}. Your questions are already assigned.`;
    $('timer').textContent='--:--:--';
    return;
  }
  if(after){
    show($('preExam'),true);
    $('preExam').querySelector('h2').textContent=currentAttempt.status==='submitted'?'Your attempt has been submitted.':'The examination window has ended.';
    $('preExamText').textContent=currentAttempt.status==='submitted'?'Your responses have been recorded.':'The C++ End Semester Practical Test closed at 11:00 AM.';
    $('preExam').querySelector('.start-time').textContent='11:00 AM';
    return;
  }
  renderTabs();renderQuestion();startClock();
}
function renderTabs(){const a=currentAttempt;$('questionTabs').innerHTML=[1,2].map(n=>{const q=n===1?{title:a.q1_title,topic:a.q1_topic}:{title:a.q2_title,topic:a.q2_topic};return `<button class="qtab ${currentQuestion===n?'active':''}" onclick="goQuestion(${n})"><small>QUESTION ${n}</small><strong>${esc(q.title)}</strong><small>${esc(q.topic)}</small></button>`}).join('')}
function renderQuestion(){const n=currentQuestion,a=currentAttempt;const q=n===1?{title:a.q1_title,text:a.q1_text,topic:a.q1_topic,code:a.code1,output:a.output1}:{title:a.q2_title,text:a.q2_text,topic:a.q2_topic,code:a.code2,output:a.output2};const savedCode=q.code?`<div class="preview"><img src="${esc(q.code)}" alt="Code submission"><button class="remove-photo" onclick="removePhoto('code')">×</button></div>`:'';const savedOut=q.output?`<div class="preview"><img src="${esc(q.output)}" alt="Output submission"><button class="remove-photo" onclick="removePhoto('output')">×</button></div>`:'';$('questions').innerHTML=`<article class="question"><div class="qmeta"><span class="qtag">QUESTION ${n} · ${esc(q.topic.toUpperCase())}</span><span class="qtag">20 MARKS</span></div><h3>${esc(q.title)}</h3><p class="scenario">${esc(q.text)}</p><div class="requirements">Write the C++ program as required. Take a clear photograph of your <b>code</b> and a clear photograph of the <b>output</b>. Do not upload unrelated images.</div><div class="upload-grid"><div class="upload-box"><h4>1. Code photograph</h4><input id="codeInput" type="file" accept="image/*" capture="environment" onchange="pickPhoto('code',this)">${savedCode}<div id="codeState" class="uploaded">${q.code?'✓ Code image saved':'No code image yet'}</div></div><div class="upload-box"><h4>2. Output photograph</h4><input id="outputInput" type="file" accept="image/*" capture="environment" onchange="pickPhoto('output',this)">${savedOut}<div id="outputState" class="uploaded">${q.output?'✓ Output image saved':'No output image yet'}</div></div></div></article>`;$('prevBtn').disabled=n===1;$('nextBtn').textContent=n===2?'Save Question':'Save & Continue';show($('submitBtn'),n===2&&currentAttempt.status==='in_progress');}
window.goQuestion=n=>{if(currentAttempt.status==='submitted')return;currentQuestion=n;renderTabs();renderQuestion()};
async function pickPhoto(kind,input){const file=input.files?.[0];if(!file)return;if(file.size>8*1024*1024){alert('Please choose an image under 8 MB.');input.value='';return}const path=`${attemptId}/q${currentQuestion}_${kind}.jpg`;const blob=await compressImage(file);const {error}=await sb.storage.from('exam-submissions').upload(path,blob,{contentType:'image/jpeg',upsert:true});if(error){alert('Upload failed: '+error.message);return}const {data:urlData}=sb.storage.from('exam-submissions').getPublicUrl(path);await savePhoto(kind,urlData.publicUrl);}
async function savePhoto(kind,url){const payload={p_attempt_id:attemptId,p_question_no:currentQuestion,p_kind:kind,p_url:url};const {data,error}=await sb.rpc('save_photo',payload);if(error||!data?.ok){alert(error?.message||data?.message||'Could not save image.');return}currentAttempt[`${kind}${currentQuestion}`]=url;if(kind==='code')currentAttempt.code1=currentQuestion===1?url:currentAttempt.code1,currentAttempt.code2=currentQuestion===2?url:currentAttempt.code2;if(kind==='output')currentAttempt.output1=currentQuestion===1?url:currentAttempt.output1,currentAttempt.output2=currentQuestion===2?url:currentAttempt.output2;renderQuestion();$('saveState').textContent='✓ Photo saved';}
async function removePhoto(kind){const {data,error}=await sb.rpc('remove_photo',{p_attempt_id:attemptId,p_question_no:currentQuestion,p_kind:kind});if(error||!data?.ok){alert(error?.message||data?.message||'Could not remove image.');return}if(kind==='code'){if(currentQuestion===1)currentAttempt.code1='';else currentAttempt.code2=''}else{if(currentQuestion===1)currentAttempt.output1='';else currentAttempt.output2=''}renderQuestion();}
async function compressImage(file){const img=await new Promise((res,rej)=>{const i=new Image();i.onload=()=>res(i);i.onerror=rej;i.src=URL.createObjectURL(file)});const max=1800,scale=Math.min(1,max/Math.max(img.width,img.height));const c=document.createElement('canvas');c.width=Math.round(img.width*scale);c.height=Math.round(img.height*scale);const ctx=c.getContext('2d');ctx.drawImage(img,0,0,c.width,c.height);return await new Promise(r=>c.toBlob(r,'image/jpeg',.78))}
async function saveCurrent(){if(!attemptId||currentAttempt.status!=='in_progress')return;const {data,error}=await sb.rpc('touch_attempt',{p_attempt_id:attemptId,p_session_id:sessionId});if(error||!data?.ok){$('saveState').textContent='Save check failed';return}$('saveState').textContent='✓ Progress saved';}
async function next(){await saveCurrent();if(currentQuestion===1){currentQuestion=2;renderTabs();renderQuestion()}else submit()}
async function submit(){if(!attemptId||currentAttempt.status==='submitted')return;if(!currentAttempt.code1||!currentAttempt.output1||!currentAttempt.code2||!currentAttempt.output2){alert('Please upload both the code and output photographs for both questions before submitting.');return}if(!confirm('Submit your C++ practical attempt? You will not be able to change it afterwards.'))return;const {data,error}=await sb.rpc('submit_attempt',{p_attempt_id:attemptId,p_session_id:sessionId});if(error||!data?.ok){alert(error?.message||data?.message||'Submission failed.');return}currentAttempt.status='submitted';renderQuestion();clearInterval(heartbeatTimer);$('submitBtn').textContent='Attempt Submitted';$('submitBtn').disabled=true;$('saveState').textContent='✓ Attempt submitted';}
function startClock(){clearInterval(clockTimer);const tick=async()=>{const start=new Date(currentAttempt.exam_start).getTime(),end=new Date(currentAttempt.exam_end).getTime(),now=Date.now();if(now<start){$('timer').textContent='--:--:--';return}if(now>=end){$('timer').textContent='00:00:00';clearInterval(clockTimer);if(currentAttempt.status==='in_progress')await autoSubmit();return}if($('activeExam').classList.contains('hidden')){show($('preExam'),false);show($('activeExam'),true);renderTabs();renderQuestion()}$('timer').textContent=formatLeft(Math.floor((end-now)/1000))};tick();clockTimer=setInterval(tick,1000)}
async function autoSubmit(){const {data,error}=await sb.rpc('submit_attempt',{p_attempt_id:attemptId,p_session_id:sessionId,p_auto:true});if(!error&&data?.ok){currentAttempt.status='submitted';renderQuestion();$('saveState').textContent='✓ Test closed at 11:00 AM';}}
function startHeartbeat(){clearInterval(heartbeatTimer);heartbeatTimer=setInterval(async()=>{if(!attemptId||currentAttempt?.status==='submitted')return;await sb.rpc('heartbeat_with_session_check',{p_attempt_id:attemptId,p_session_id:sessionId})},15000)}
async function proctor(eventType,detail=''){if(proctorBusy||!attemptId||currentAttempt?.status==='submitted')return;proctorBusy=true;const {data}=await sb.rpc('record_proctor_event',{p_attempt_id:attemptId,p_session_id:sessionId,p_event_type:eventType,p_detail:detail});proctorBusy=false;if(data?.ok){$('integrityBadge').textContent=`● Test integrity: ${data.warning_count?data.warning_count+' warning'+(data.warning_count>1?'s':''):'normal'}`;$('integrityBadge').className='integrity '+(data.warning_count?'warn':'ok');if(data.warning_count)showWarning(data.warning_count,eventType)}}
function showWarning(count,event){$('warningText').textContent=`Leaving or changing the examination screen was recorded (${event.replaceAll('_',' ').toLowerCase()}). Warning ${count} has been recorded. Return to the test.`;show($('warningModal'),true)}
document.addEventListener('visibilitychange',()=>{if(document.hidden)proctor('APP_BACKGROUND','Page became hidden');else if(attemptId)proctor('RETURNED_TO_TEST','Page became visible')});window.addEventListener('blur',()=>{if(document.visibilityState==='visible')proctor('WINDOW_BLUR','Window lost focus')});window.addEventListener('pageshow',()=>{if(attemptId)sb.rpc('heartbeat',{p_attempt_id:attemptId,p_session_id:sessionId})});


$('startBtn').onclick=start;
$('regInput').addEventListener('keydown',e=>{if(e.key==='Enter')start()});
$('nextBtn').onclick=next;
$('prevBtn').onclick=()=>{if(currentQuestion>1){currentQuestion--;renderTabs();renderQuestion()}};
$('submitBtn').onclick=submit;
$('warningClose').onclick=()=>show($('warningModal'),false);

(async()=>{if(attemptId)await loadAttempt()})();
