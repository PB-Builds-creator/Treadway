"use strict";
/* ============================================================================
   Cairn — synced web app.
   Auth + data via Supabase (per-user, row-level-secured). The UI renders from a
   local `state` mirror for instant response; every change is cached to this
   device AND pushed to Supabase, so it syncs across your devices and stays
   usable offline. Date/recurrence/streak logic is the same verified core as the
   local preview.
============================================================================ */

const CFG = window.CAIRN_CONFIG || {};
const SB = window.supabase.createClient(CFG.SUPABASE_URL, CFG.SUPABASE_ANON_KEY, {
  auth: { persistSession: true, autoRefreshToken: true }
});

const TZ = "America/Denver";
const root = document.getElementById("root");

let session = null, userId = null;
let state = null;                 // {name,accent,goalOz,tasks,completions,hydration}
let tab = "today";
let authMode = "signin";
let syncOn = navigator.onLine;
let outbox = [];                  // queued writes when offline / on error
let access = { status: "approved", isAdmin: false }; // membership gate
let unlocked = false;             // PIN-lock state (per app session)
let entry = "", setupFirst = null, hiddenAt = 0;
const LOCK_GRACE = 60000;         // re-lock after 60s in the background

/* ---------- Mountain-Time helpers (verified core) ---------- */
function denverParts(d=new Date()){
  const f=new Intl.DateTimeFormat("en-US",{timeZone:TZ,year:"numeric",month:"2-digit",day:"2-digit",hour:"2-digit",minute:"2-digit",hour12:false,weekday:"short"});
  const p={};for(const x of f.formatToParts(d))p[x.type]=x.value;return p;
}
function todayStr(d=new Date()){const p=denverParts(d);return `${p.year}-${p.month}-${p.day}`;}
function tzAbbr(){const s=new Intl.DateTimeFormat("en-US",{timeZone:TZ,timeZoneName:"short"}).formatToParts(new Date()).find(x=>x.type==="timeZoneName");return s?s.value:"MT";}
function ymdToUTC(ymd){const[y,m,d]=ymd.split("-").map(Number);return new Date(Date.UTC(y,m-1,d));}
function utcToYmd(dt){return `${dt.getUTCFullYear()}-${String(dt.getUTCMonth()+1).padStart(2,"0")}-${String(dt.getUTCDate()).padStart(2,"0")}`;}
function addDays(ymd,n){const dt=ymdToUTC(ymd);dt.setUTCDate(dt.getUTCDate()+n);return utcToYmd(dt);}
function weekdayOf(ymd){return ymdToUTC(ymd).getUTCDay();}
function prettyDate(ymd){return ymdToUTC(ymd).toLocaleDateString("en-US",{weekday:"long",month:"long",day:"numeric",timeZone:"UTC"});}
const WD_SHORT=["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];

/* ---------- Icons ---------- */
const ICON={
  check:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12.5l5 5L20 6.5"/></svg>',
  today:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="4.2"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4" stroke-linecap="round"/></svg>',
  week:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="4.5" width="18" height="16" rx="2.5"/><path d="M3 9h18M8 2.5v4M16 2.5v4" stroke-linecap="round"/></svg>',
  history:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M4 6v13h16M8 15l3-4 3 3 4-6"/></svg>',
  settings:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="3.2"/><path d="M12 3v2.2M12 18.8V21M21 12h-2.2M5.2 12H3M18.4 5.6l-1.6 1.6M7.2 16.8l-1.6 1.6M18.4 18.4l-1.6-1.6M7.2 7.2L5.6 5.6" stroke-linecap="round"/></svg>',
  lock:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><rect x="4.5" y="10.5" width="15" height="10.5" rx="2.5"/><path d="M8 10.5V7a4 4 0 018 0v3.5"/></svg>',
  pencil:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20h4L19 9a2.1 2.1 0 0 0-3-3L5 17v3z"/><path d="M14.5 6.5l3 3"/></svg>',
  trash:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V5h6v2M6.5 7l1 13h9l1-13"/></svg>',
  cairn:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M8 21h8M6.5 17.5h11M9 14h6M10 10.6h4M11 7.4h2" stroke-linecap="round"/></svg>',
  drop:"💧",pills:"💊",fork:"🍽️",book:"📖",hands:"🙏",chart:"📈",run:"🏃",moon:"🌙",sun:"☀️",heart:"❤️",leaf:"🍃",cup:"☕",star:"⭐",flag:"🚩",dumbbell:"🏋️"
};
function symChar(s){return ICON[s]&&ICON[s].length<5?ICON[s]:"•";}
const SYMS=["drop","pills","fork","book","hands","chart","run","moon","sun","heart","leaf","cup","star","check","flag","dumbbell"];
const ACCENTS={slate:"#5b7089",clay:"#a86b63",sage:"#5f7d62",amber:"#a5834a",plum:"#7b6395",teal:"#4d8384",
  graphite:"#6d7178",rose:"#a8757f",ocean:"#547d97",olive:"#7c7d54",mauve:"#8a7791",ember:"#a86a55"};
const GROUPS=[{k:"morning",t:"Morning"},{k:"daytime",t:"Daytime"},{k:"trading",t:"Trading"},{k:"evening",t:"Evening"},{k:"bed",t:"Before Bed"},{k:"anytime",t:"Anytime"}];

/* ---------- Preset routines (first-run) ---------- */
const uid=()=> (crypto.randomUUID? crypto.randomUUID() : "t"+Date.now()+Math.random().toString(16).slice(2));
// New members always start with a blank task page — no one else's routine is seeded
// or even present in this source.
function presetEmpty(){return {name:"Me",accent:"slate",goalOz:200,tasks:[]};}

/* ---------- Recurrence / streaks / hydration (verified core) ---------- */
function occurs(task,ymd){const r=task.rule||{type:"daily"};
  if(r.type==="daily")return true;
  if(r.type==="weekdays")return (r.days||[]).includes(weekdayOf(ymd));
  if(r.type==="weekly")return weekdayOf(ymd)===r.day;
  return true;}
function statusOf(ymd,taskId){return (state.completions[ymd]||{})[taskId]||null;}
function dueTasks(ymd){return state.tasks.filter(t=>!t.archived&&occurs(t,ymd));}
function dayFraction(ymd){const due=dueTasks(ymd);if(!due.length)return{done:0,total:0,frac:0};
  const done=due.filter(t=>statusOf(ymd,t.id)==="done").length;return{done,total:due.length,frac:done/due.length};}
function isRestDay(ymd){return !!state && Array.isArray(state.restDays) && state.restDays.includes(ymd);}
function isSavedDay(ymd){return !!state && Array.isArray(state.savedDays) && state.savedDays.includes(ymd);}
function isProtected(ymd){return isRestDay(ymd)||isSavedDay(ymd);}   // neutral for streaks
function daySuccess(ymd){const due=dueTasks(ymd);if(!due.length)return false;
  if(due.every(t=>statusOf(ymd,t.id)==="done"))return true;   // everything done
  const keys=due.filter(t=>t.keystone);                        // …or all non-negotiables done
  return keys.length>0 && keys.every(t=>statusOf(ymd,t.id)==="done");}
function currentStreak(){let ymd=todayStr(),s=0,g=0;if(isProtected(ymd)||!daySuccess(ymd))ymd=addDays(ymd,-1);
  while(g++<400){
    if(isProtected(ymd)){ymd=addDays(ymd,-1);continue;}          // rest/saved day: neutral
    const due=dueTasks(ymd);if(!due.length){ymd=addDays(ymd,-1);continue;}
    if(daySuccess(ymd)){s++;ymd=addDays(ymd,-1);}else break;}return s;}
function longestStreak(days=180){let ymd=addDays(todayStr(),-days),run=0,best=0;
  for(let i=0;i<=days;i++){
    if(!isProtected(ymd)){const due=dueTasks(ymd);if(due.length){if(daySuccess(ymd)){run++;best=Math.max(best,run);}else run=0;}}
    ymd=addDays(ymd,1);}return best;}
function taskStreak(task){let ymd=todayStr(),s=0,g=0;if(statusOf(ymd,task.id)!=="done")ymd=addDays(ymd,-1);
  while(g++<400){
    if(isProtected(ymd)){ymd=addDays(ymd,-1);continue;}
    if(!occurs(task,ymd)){ymd=addDays(ymd,-1);continue;}
    if(statusOf(ymd,task.id)==="done"){s++;ymd=addDays(ymd,-1);}else break;}return s;}

/* Streak-save: once per calendar month, retroactively protect the most recent
   missed scheduled day so it doesn't break the streak. */
function mostRecentMiss(lookback=14){
  let ymd=addDays(todayStr(),-1);               // today (pending) is never a "miss"
  for(let i=0;i<lookback;i++){
    if(!isProtected(ymd)){const due=dueTasks(ymd);if(due.length&&!daySuccess(ymd))return ymd;}
    ymd=addDays(ymd,-1);
  }
  return null;
}
function saveAvailableThisMonth(){
  const m=todayStr().slice(0,7);
  return !(Array.isArray(state.savedDays)&&state.savedDays.some(d=>String(d).slice(0,7)===m));
}
function canSaveStreak(){
  if(!saveAvailableThisMonth())return false;
  const d=mostRecentMiss();if(!d)return false;
  // Only offer it when protecting that miss would actually lengthen the streak
  // (i.e. there's a real streak behind it worth saving — not just empty history).
  const before=currentStreak();
  const prev=state.savedDays;state.savedDays=[...(prev||[]),d];
  const after=currentStreak();
  state.savedDays=prev;
  return after>before;
}
function saveStreak(){
  const d=mostRecentMiss();
  if(!d||!saveAvailableThisMonth())return;
  if(!Array.isArray(state.savedDays))state.savedDays=[];
  state.savedDays=[...state.savedDays,d];
  mSaveProfile();
}
function hydOz(ymd){return state.hydration[ymd]||0;}

/* =====================================================================
   DATA LAYER (Supabase + local cache + offline outbox)
===================================================================== */
const cacheKey=()=>"cairn_cache_"+userId;
function cacheSave(){try{localStorage.setItem(cacheKey(),JSON.stringify(state));}catch(e){}}
function cacheLoad(){try{const r=localStorage.getItem(cacheKey());return r?JSON.parse(r):null;}catch(e){return null;}}

function rowToTask(r){return{id:r.id,title:r.title,sym:r.sym,group:r.group_key,time:r.time||"",pri:!!r.pri,rule:r.rule||{type:"daily"},hydration:!!r.hydration,appUrl:r.app_url||"",keystone:!!r.keystone,measureUnit:r.measure_unit||"",remind:r.remind!==false,sort_index:r.sort_index||0,archived:!!r.archived};}
function taskToRow(t,i){return{id:t.id,user_id:userId,title:t.title,sym:t.sym,group_key:t.group,time:t.time||"",pri:!!t.pri,rule:t.rule,hydration:!!t.hydration,app_url:t.appUrl||null,keystone:!!t.keystone,measure_unit:t.measureUnit||null,remind:t.remind!==false,sort_index:(i??t.sort_index??0),archived:!!t.archived,updated_at:new Date().toISOString()};}

async function loadAll(){
  const since=addDays(todayStr(),-90);
  const [prof,tasks,comps,hyd]=await Promise.all([
    SB.from("profiles").select("*").eq("user_id",userId).maybeSingle(),
    SB.from("tasks").select("*").eq("user_id",userId).order("sort_index"),
    SB.from("completions").select("task_id,day,status").eq("user_id",userId).gte("day",since),
    SB.from("hydration").select("day,oz").eq("user_id",userId).gte("day",since)
  ]);
  if(prof.error||tasks.error||comps.error||hyd.error)
    throw (prof.error||tasks.error||comps.error||hyd.error);
  if(!prof.data) return {needsOnboarding:true};
  const completions={};for(const c of comps.data){(completions[c.day]||(completions[c.day]={}))[c.task_id]=c.status;}
  const hydration={};for(const h of hyd.data){hydration[h.day]=Number(h.oz);}
  state={name:prof.data.name,accent:prof.data.accent,goalOz:prof.data.goal_oz,
    tasks:tasks.data.map(rowToTask),completions,hydration,
    restDays:Array.isArray(prof.data.rest_days)?prof.data.rest_days:[],
    savedDays:Array.isArray(prof.data.saved_days)?prof.data.saved_days:[]};
  await loadCouple();
  await loadNotes();
  await loadSummaryTime();
  await loadValues();
  cacheSave();
  pushDailyStatus();
  return {ok:true};
}
async function loadNotes(){
  try{const since=addDays(todayStr(),-90);
    const {data}=await SB.from("notes").select("day,text").eq("user_id",userId).gte("day",since);
    state.notes={};for(const n of (data||[]))state.notes[n.day]=n.text;
  }catch(e){state.notes=state.notes||{};}
}
async function loadSummaryTime(){
  try{const {data}=await SB.from("reminder_settings").select("summary_time,quiet_start,quiet_end").eq("user_id",userId).maybeSingle();
    state.summaryTime=(data&&data.summary_time)||"21:30";
    state.quietStart=(data&&data.quiet_start)||"";state.quietEnd=(data&&data.quiet_end)||"";
  }catch(e){state.summaryTime=state.summaryTime||"21:30";}
}
async function loadValues(){
  try{const since=addDays(todayStr(),-90);
    const {data}=await SB.from("task_values").select("task_id,day,value").eq("user_id",userId).gte("day",since);
    state.values={};for(const v of (data||[]))state.values[v.task_id+"#"+v.day]=Number(v.value);
  }catch(e){state.values=state.values||{};}
}
function valueFor(taskId,ymd){return (state.values&&state.values[taskId+"#"+ymd])||0;}
function mSetValue(taskId,ymd,val){
  val=Math.max(0,Number(val)||0);
  if(!state.values)state.values={};
  state.values[taskId+"#"+ymd]=val;
  if(!state.completions[ymd])state.completions[ymd]={};
  if(val>0)state.completions[ymd][taskId]="done";else delete state.completions[ymd][taskId];
  cacheSave();render();pushDailyStatus();
  push(()=>SB.from("task_values").upsert({user_id:userId,task_id:taskId,day:ymd,value:val,updated_at:new Date().toISOString()},{onConflict:"user_id,task_id,day"}));
  if(val>0)push(()=>SB.from("completions").upsert({user_id:userId,task_id:taskId,day:ymd,status:"done",updated_at:new Date().toISOString()},{onConflict:"user_id,task_id,day"}));
  else push(()=>SB.from("completions").delete().match({user_id:userId,task_id:taskId,day:ymd}));
}
function noteFor(ymd){return (state.notes&&state.notes[ymd])||"";}
function setNote(ymd,text){
  if(!state.notes)state.notes={};
  if(text)state.notes[ymd]=text;else delete state.notes[ymd];
  render();
  push(()=>SB.from("notes").upsert({user_id:userId,day:ymd,text:text||"",updated_at:new Date().toISOString()},{onConflict:"user_id,day"}));
}

/* Partner (couple layer): who I'm linked to + their shared daily summary. */
async function loadCouple(){
  try{
    const {data:link}=await SB.from("couple_links").select("partner_id").eq("user_id",userId).maybeSingle();
    state.partnerId=(link&&link.partner_id)||null;
    if(state.partnerId){
      const [{data:pp},{data:ps}]=await Promise.all([
        SB.from("profiles").select("name,accent").eq("user_id",state.partnerId).maybeSingle(),
        SB.from("daily_status").select("done,total,all_done").eq("user_id",state.partnerId).eq("day",todayStr()).maybeSingle()
      ]);
      state.partnerName=(pp&&pp.name)||"Your partner";
      state.partnerStatus=ps||null;
    }else{state.partnerName=null;state.partnerStatus=null;}
  }catch(e){/* couple layer is optional; never block core load */}
}
/* All-time "compounding" totals — quiet true numbers, loaded lazily for History. */
async function loadTotals(){
  try{
    const [c,h]=await Promise.all([
      SB.from("completions").select("*",{count:"exact",head:true}).eq("status","done"),
      SB.from("hydration").select("oz")
    ]);
    const oz=(h.data||[]).reduce((s,r)=>s+Number(r.oz||0),0);
    state.totals={done:c.count||0,oz:Math.round(oz)};
    state.totalsLoaded=true;
    if(tab==="history")render();
  }catch(e){state.totalsLoaded=true;}
}

/* Share my day's counts (not my tasks) so my partner can see a gentle signal. */
function pushDailyStatus(){
  if(!state)return;
  const t=todayStr(),f=dayFraction(t);
  push(()=>SB.from("daily_status").upsert(
    {user_id:userId,day:t,done:f.done,total:f.total,all_done:f.total>0&&f.done>=f.total,updated_at:new Date().toISOString()},
    {onConflict:"user_id,day"}));
}

/* fire-and-forget push; queues to outbox on failure so nothing is lost offline */
async function push(fn){
  try{const {error}=await fn();if(error)throw error;setSync(true);flushOutbox();}
  catch(e){outbox.push(fn);setSync(false);}
}
async function flushOutbox(){
  if(!outbox.length)return;const items=outbox.slice();outbox=[];
  for(const fn of items){try{const{error}=await fn();if(error)throw error;}catch(e){outbox.push(fn);}}
  setSync(outbox.length===0);
}
function setSync(on){syncOn=on;const el=document.getElementById("syncdot");if(el)el.className="syncdot"+(on?"":" off");}

/* transient one-shot animation flags (consumed by the next render) */
let justCompletedId=null, justAddedId=null, ringLast=0, ringWait=0, streakLast=null, waterLast=null, waterPulse=false, rowStagger=0;
let launchEl=null, launchTimer=0, launchStarted=0;
function prefersReduce(){return !!(window.matchMedia&&window.matchMedia("(prefers-reduced-motion:reduce)").matches);}
function cairnHtml(cls=""){return `<div class="cairnstack ${cls}"><i></i><i></i><i></i><i></i><i></i></div>`;}
function startLaunch(){
  if(prefersReduce()||launchEl)return;
  launchStarted=performance.now();
  launchEl=document.createElement("div");launchEl.className="launch";
  launchEl.innerHTML=`<div class="launchmark">${cairnHtml("launchcairn")}<span>Cairn</span></div>`;
  document.body.appendChild(launchEl);
  launchEl.addEventListener("pointerdown",()=>finishLaunch(true),{once:true});
  launchTimer=setTimeout(()=>finishLaunch(false),680);
}
function finishLaunch(skip){
  if(!launchEl)return;clearTimeout(launchTimer);
  const ov=launchEl,stack=ov.querySelector(".cairnstack"),ring=root.querySelector(".ring");launchEl=null;
  if(skip||prefersReduce()){ov.remove();return;}
  if(ring&&stack){
    const a=stack.getBoundingClientRect(),b=ring.getBoundingClientRect();
    const dx=b.left+b.width/2-a.left-a.width/2,dy=b.top+b.height/2-a.top-a.height/2,sc=b.width/a.width;
    stack.animate([{transform:"translate(0,0) scale(1)",opacity:1},{transform:`translate(${dx}px,${dy}px) scale(${sc})`,opacity:.12}],{duration:210,easing:"cubic-bezier(.3,0,.15,1)",fill:"forwards"});
    ov.animate([{opacity:1},{opacity:0}],{duration:210,easing:"cubic-bezier(.4,0,.7,1)",fill:"forwards"});
    setTimeout(()=>ov.remove(),220);
  }else{ov.classList.add("leaving");setTimeout(()=>ov.remove(),180);}
}
function resolveLaunch(){if(launchEl&&root.querySelector(".ring")&&performance.now()-launchStarted<640)finishLaunch(false);}
/* mutations: update local state instantly, cache, render, then push */
/* FLIP: remember where every row is, then glide each from its old spot to its new one. */
function captureRows(){
  const m=new Map();
  root.querySelectorAll(".rowwrap[data-rid]").forEach(el=>m.set(el.dataset.rid,el.getBoundingClientRect()));
  return m;
}
function playFlip(first){
  if(!first||prefersReduce())return;
  root.querySelectorAll(".rowwrap[data-rid]").forEach(el=>{
    const f=first.get(el.dataset.rid);if(!f)return;
    const l=el.getBoundingClientRect();
    const dx=f.left-l.left,dy=f.top-l.top;
    if(Math.abs(dx)<1&&Math.abs(dy)<1)return;
    el.style.transition="none";el.style.transform=`translate(${dx}px,${dy}px)`;el.style.zIndex="4";
    requestAnimationFrame(()=>{
      el.style.transition="transform .44s cubic-bezier(.2,.8,.25,1)";
      el.style.transform="";
      setTimeout(()=>{el.style.transition="";el.style.zIndex="";},470);
    });
  });
}
function mSetStatus(taskId,ymd,st){
  const first=(ymd===todayStr()&&tab==="today")?captureRows():null;
  if(!state.completions[ymd])state.completions[ymd]={};
  if(st===null)delete state.completions[ymd][taskId];else state.completions[ymd][taskId]=st;
  justCompletedId=(st==="done"&&ymd===todayStr())?taskId:null;
  ringWait=(st==="done"&&first)?90:0;
  cacheSave();render();justCompletedId=null;playFlip(first);
  if(st===null) push(()=>SB.from("completions").delete().match({user_id:userId,task_id:taskId,day:ymd}));
  else push(()=>SB.from("completions").upsert({user_id:userId,task_id:taskId,day:ymd,status:st,updated_at:new Date().toISOString()},{onConflict:"user_id,task_id,day"}));
  pushDailyStatus();   // keep the shared "today" signal fresh for my partner
}
function mAddWater(oz){if(!(oz>0))return;const t=todayStr();state.hydration[t]=(state.hydration[t]||0)+oz;waterPulse=true;cacheSave();render();waterPulse=false;
  push(()=>SB.from("hydration").upsert({user_id:userId,day:t,oz:state.hydration[t],updated_at:new Date().toISOString()},{onConflict:"user_id,day"}));}
function mUpsertTask(t){const i=state.tasks.findIndex(x=>x.id===t.id);
  if(i>=0)state.tasks[i]=t;else{t.sort_index=state.tasks.length;state.tasks.push(t);justAddedId=t.id;}
  cacheSave();render();justAddedId=null;push(()=>SB.from("tasks").upsert(taskToRow(t,t.sort_index)));}
function mDeleteTask(id){state.tasks=state.tasks.filter(x=>x.id!==id);for(const d in state.completions)delete state.completions[d][id];
  cacheSave();render();push(()=>SB.from("tasks").delete().match({user_id:userId,id}));}
/* Delete with a 4.5s undo window — the server delete is deferred until the toast clears. */
function mDeleteWithUndo(id){
  const task=state.tasks.find(x=>x.id===id);if(!task)return;
  const backup=JSON.parse(JSON.stringify(task));
  state.tasks=state.tasks.filter(x=>x.id!==id);cacheSave();render();
  let committed=false;
  const timer=setTimeout(()=>{committed=true;
    push(()=>SB.from("tasks").delete().match({user_id:userId,id}));
    push(()=>SB.from("completions").delete().match({user_id:userId,task_id:id}));
  },4500);
  showToast(`Deleted “${task.title}”`,"Undo",()=>{ if(committed)return; clearTimeout(timer); state.tasks.push(backup); cacheSave(); render(); });
}
function mArchive(id,val){
  const t=state.tasks.find(x=>x.id===id);if(!t)return;t.archived=val;
  cacheSave();render();push(()=>SB.from("tasks").update({archived:val,updated_at:new Date().toISOString()}).eq("user_id",userId).eq("id",id));
}
function mDuplicate(task){
  const c=JSON.parse(JSON.stringify(task));c.id=uid();c.title=(task.title||"Task")+" copy";c.sort_index=state.tasks.length;c.archived=false;
  state.tasks.push(c);cacheSave();render();push(()=>SB.from("tasks").upsert(taskToRow(c,c.sort_index)));
}
function mMove(id,dir){ // reorder active tasks by swapping with a neighbour
  const active=state.tasks.filter(t=>!t.archived).sort((a,b)=>(a.sort_index||0)-(b.sort_index||0));
  const i=active.findIndex(t=>t.id===id),j=i+dir;if(i<0||j<0||j>=active.length)return;
  const tmp=active[i];active[i]=active[j];active[j]=tmp;
  active.forEach((t,k)=>t.sort_index=k);
  cacheSave();render();
  for(const t of active)push(()=>SB.from("tasks").upsert(taskToRow(t,t.sort_index)));
}
function quickAdd(title,sym,hydration){
  mUpsertTask({id:uid(),title,sym,group:"anytime",time:"",rule:{type:"daily"},hydration:!!hydration,sort_index:state.tasks.length});
}
function showToast(msg,label,onAction){
  const ex=document.getElementById("cairn-toast");if(ex)ex.remove();
  const el=document.createElement("div");el.id="cairn-toast";el.className="toast";
  el.innerHTML=`<span>${escapeHtml(msg)}</span>${label?`<button id="toast-act">${escapeHtml(label)}</button>`:""}`;
  document.body.appendChild(el);
  const act=el.querySelector("#toast-act");if(act&&onAction)act.onclick=()=>{onAction();el.remove();};
  setTimeout(()=>{if(el.parentNode)el.remove();},4300);
}
function mSaveProfile(){cacheSave();render();
  push(()=>SB.from("profiles").upsert({user_id:userId,name:state.name,accent:state.accent,goal_oz:state.goalOz,rest_days:state.restDays||[],saved_days:state.savedDays||[],updated_at:new Date().toISOString()}));}

async function onboard(preset){
  state={name:preset.name,accent:preset.accent,goalOz:preset.goalOz,tasks:preset.tasks,completions:{},hydration:{}};
  cacheSave();tab="today";showApp();
  await push(()=>SB.from("profiles").upsert({user_id:userId,name:state.name,accent:state.accent,goal_oz:state.goalOz,updated_at:new Date().toISOString()}));
  if(state.tasks.length) await push(()=>SB.from("tasks").upsert(state.tasks.map((t,i)=>taskToRow(t,i))));
}

/* =====================================================================
   AUTH
===================================================================== */
async function boot(){
  const {data}=await SB.auth.getSession();
  session=data.session;userId=session?.user?.id||null;
  if(!session){renderAuth();return;}
  await enterApp();
}
SB.auth.onAuthStateChange((_e,s)=>{session=s;userId=s?.user?.id||null;});

async function loadAccess(){
  try{
    const {data,error}=await SB.from("access").select("status,is_admin").eq("user_id",userId).maybeSingle();
    if(error)throw error;
    if(!data){
      const email=(session&&session.user&&session.user.email)||null;
      await SB.from("access").insert({user_id:userId,email,status:"pending"});
      access={status:"pending",isAdmin:false};
    }else{access={status:data.status,isAdmin:!!data.is_admin};}
  }catch(e){access={status:"approved",isAdmin:false};} // table absent => don't lock existing users out
  return access;
}
async function enterApp(){
  root.innerHTML='<div class="loading"><div class="spin"></div></div>';
  await loadAccess();
  if(access.status!=="approved"){renderPending();return;}
  const cached=cacheLoad();
  try{
    const r=await loadAll();
    if(r.needsOnboarding){ if(cached&&cached.tasks&&cached.tasks.length){state=cached;showApp();} else {renderOnboard();return;} }
    else showApp();
  }catch(e){
    if(cached){state=cached;setSync(false);showApp();}          // offline: run from cache
    else{renderAuth("Couldn't reach the server. Check your connection and try again.");}
  }
}
async function doAuth(email,password,name){
  const btn=document.getElementById("a-btn");const err=document.getElementById("a-err");
  err.textContent="";btn.disabled=true;btn.textContent=authMode==="signup"?"Creating…":"Signing in…";
  try{
    const fn=authMode==="signup"?SB.auth.signUp({email,password}):SB.auth.signInWithPassword({email,password});
    const {data,error}=await fn;
    if(error)throw error;
    if(!data.session){ // e.g. email confirmation still on
      err.textContent="Check your email to confirm, then sign in. (Or turn off 'Confirm email' in Supabase → Authentication.)";
      btn.disabled=false;btn.textContent=labelFor();return;
    }
    session=data.session;userId=session.user.id;
    if(name){try{localStorage.setItem("cairn_name_"+userId,name);}catch(_){}}
    await enterApp();
  }catch(e){
    err.textContent=friendlyAuthError(e);btn.disabled=false;btn.textContent=labelFor();
  }
}
function friendlyAuthError(e){const m=(e&&e.message||"").toLowerCase();
  if(m.includes("invalid login"))return "Wrong email or password.";
  if(m.includes("already registered")||m.includes("already been"))return "That email already has an account — try signing in.";
  if(m.includes("password"))return "Password must be at least 6 characters.";
  if(m.includes("email"))return "Please enter a valid email.";
  return e&&e.message?e.message:"Something went wrong. Try again.";}
function labelFor(){return authMode==="signup"?"Request access":"Sign in";}
async function signOut(){await SB.auth.signOut();state=null;userId=null;session=null;unlocked=false;entry="";setupFirst=null;renderAuth();}

/* =====================================================================
   RENDER
===================================================================== */
/* ---------- Push reminders (Phase 1: subscribe this device) ---------- */
const VAPID_PUBLIC = CFG.VAPID_PUBLIC_KEY || "";
let remindersFlag = false;
function urlB64ToUint8Array(base64){
  const pad="=".repeat((4-base64.length%4)%4);
  const b64=(base64+pad).replace(/-/g,"+").replace(/_/g,"/");
  const raw=atob(b64);const out=new Uint8Array(raw.length);
  for(let i=0;i<raw.length;i++)out[i]=raw.charCodeAt(i);return out;
}
function pushSupported(){return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window;}
function isStandalone(){return window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone===true;}
async function currentSubscription(){
  if(!pushSupported())return null;
  try{const reg=await navigator.serviceWorker.ready;return await reg.pushManager.getSubscription();}catch(e){return null;}
}
async function remindersOn(){return pushSupported() && Notification.permission==="granted" && !!(await currentSubscription());}
async function updateReminderLabel(){
  remindersFlag=await remindersOn();
  const el=document.getElementById("remVal");if(el)el.textContent=(remindersFlag?"On":"Off")+" ›";
}
async function enableReminders(){
  if(!pushSupported()){alert("This browser can't do reminders. On iPhone, add Cairn to your Home Screen first, then open it from there.");return;}
  if(/iphone|ipad|ipod/i.test(navigator.userAgent) && !isStandalone()){
    alert("On iPhone: tap the Share button → Add to Home Screen, then open Cairn from the Home Screen and turn reminders on there.");return;
  }
  const perm=await Notification.requestPermission();
  if(perm!=="granted"){alert("Notifications are blocked. Allow them for Cairn in Settings, then try again.");return;}
  try{
    const reg=await navigator.serviceWorker.ready;
    let sub=await reg.pushManager.getSubscription();
    if(!sub)sub=await reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:urlB64ToUint8Array(VAPID_PUBLIC)});
    const j=sub.toJSON();
    await SB.from("push_subscriptions").upsert({user_id:userId,endpoint:j.endpoint,p256dh:j.keys.p256dh,auth:j.keys.auth,updated_at:new Date().toISOString()},{onConflict:"endpoint"});
    await SB.from("reminder_settings").upsert({user_id:userId,enabled:true,updated_at:new Date().toISOString()});
    reg.showNotification("Reminders on",{body:"Cairn will nudge you at your task times and each night.",icon:"icon-192.png"});
    remindersFlag=true;render();
  }catch(e){alert("Couldn't turn on reminders: "+(e&&e.message||e));}
}
async function disableReminders(){
  try{
    const sub=await currentSubscription();
    if(sub){const j=sub.toJSON();await SB.from("push_subscriptions").delete().match({user_id:userId,endpoint:j.endpoint});await sub.unsubscribe();}
    await SB.from("reminder_settings").upsert({user_id:userId,enabled:false,updated_at:new Date().toISOString()});
    remindersFlag=false;render();
  }catch(e){alert("Couldn't turn off reminders: "+(e&&e.message||e));}
}

function setAccent(){const a=state?ACCENTS[state.accent]||ACCENTS.slate:ACCENTS.slate;
  document.documentElement.style.setProperty("--accent",a);
  document.documentElement.style.setProperty("--accent-soft",a+"22");}

/* ---------- App-lock: a per-device PIN on top of the account login ----------
   Real access control is the account (email+password) + row-level security +
   disabled sign-ups. This PIN is the quick lock so an already-signed-in device
   opens to a code pad instead of straight to your data. Codes are never shown. */
function lockKey(){return "cairn_lock_"+userId;}
function getLockCode(){try{return localStorage.getItem(lockKey())||null;}catch(e){return null;}}
function setLockCode(c){try{localStorage.setItem(lockKey(),c);}catch(e){}}
function keypadHtml(){return [1,2,3,4,5,6,7,8,9].map(n=>`<button class="key" data-k="${n}">${n}</button>`).join("")+`<button class="key blank"></button><button class="key" data-k="0">0</button><button class="key" data-k="del">⌫</button>`;}
function dotsHtml(){const n=Math.max(4,entry.length);return Array.from({length:n}).map((_,i)=>`<i class="${i<entry.length?"f":""}"></i>`).join("");}
function bindKeys(onDone,onSignout){
  root.querySelectorAll(".key[data-k]").forEach(b=>b.onclick=()=>{
    const k=b.dataset.k;
    if(k==="del")entry=entry.slice(0,-1);else if(entry.length<4)entry+=k;
    const d=document.getElementById("dots");if(d)d.innerHTML=dotsHtml();
    if(entry.length===4)setTimeout(()=>onDone(entry),110);
  });
  const so=root.querySelector("[data-signout]");if(so&&onSignout)so.onclick=onSignout;
}
function shakeLock(then){const l=document.getElementById("lock");if(l)l.classList.add("shake");setTimeout(then,420);}

function lockSkipped(){try{return localStorage.getItem("cairn_lockskip_"+userId)==="1";}catch(e){return false;}}
function markLockSkipped(){try{localStorage.setItem("cairn_lockskip_"+userId,"1");}catch(e){}}
function homeTipSeen(){try{return localStorage.getItem("cairn_hometip_"+userId)==="1";}catch(e){return false;}}
function markHomeTipSeen(){try{localStorage.setItem("cairn_hometip_"+userId,"1");}catch(e){}}

/* Gate: PIN (if one is set) → first-run choice to set a code OR skip → one-time
   "add to Home Screen" tip (Safari, only if not already installed) → the app. */
function showApp(){
  if(!state){renderAuth();return;}
  if(!unlocked){
    if(getLockCode()){renderLockEnter();return;}      // returning device with a code
    if(!lockSkipped()){renderLockSetup(true);return;}  // first run: set a code OR skip
    unlocked=true;                                      // skipped → open freely
  }
  render();
  if(!tourSeen()){pendingTour=false;markTourSeen();setTimeout(runTour,300);} // once for anyone who hasn't seen it (tour includes the add-to-home-screen step)
}
function renderLockEnter(){
  setAccent();entry="";
  root.innerHTML=`<div class="screen"><div class="lock" id="lock">
    <div class="glyph">${ICON.lock}</div><h1>Cairn</h1><p>Enter your code</p>
    <div class="dots" id="dots">${dotsHtml()}</div>
    <div class="keypad">${keypadHtml()}</div>
    <button class="swap" data-signout="1">Forgot code? Sign out</button></div></div>`;
  bindKeys(
    (code)=>{ if(code===getLockCode()){unlocked=true;entry="";showApp();} else shakeLock(()=>{entry="";renderLockEnter();}); },
    ()=>{ if(confirm("This signs you out on this device so you can set a new code. Continue?")){try{localStorage.removeItem(lockKey());}catch(e){}signOut();} }
  );
}
function renderLockSetup(firstRun){
  setAccent();entry="";const confirming=setupFirst!==null;
  const foot = confirming ? '<button class="swap" data-restart="1">Start over</button>'
    : firstRun ? '<button class="swap" data-skip="1">Skip — open without a code</button>'
    : '<button class="swap" data-cancel="1">Cancel</button>';
  root.innerHTML=`<div class="screen"><div class="lock" id="lock">
    <div class="glyph">${ICON.lock}</div><h1>${confirming?"Confirm your code":"Set an unlock code"}</h1>
    <p>${confirming?"Enter the same 4 digits again":"Optional — a 4-digit code that locks the app on this device. You can skip it and open freely."}</p>
    <div class="dots" id="dots">${dotsHtml()}</div>
    <div class="keypad">${keypadHtml()}</div>
    ${foot}</div></div>`;
  bindKeys((code)=>{
    if(!confirming){setupFirst=code;entry="";renderLockSetup(firstRun);}
    else if(code===setupFirst){setLockCode(code);setupFirst=null;entry="";unlocked=true;showApp();}
    else shakeLock(()=>{setupFirst=null;entry="";renderLockSetup(firstRun);});
  });
  const rs=root.querySelector("[data-restart]");if(rs)rs.onclick=()=>{setupFirst=null;entry="";renderLockSetup(firstRun);};
  const sk=root.querySelector("[data-skip]");if(sk)sk.onclick=()=>{markLockSkipped();unlocked=true;entry="";setupFirst=null;showApp();};
  const cn=root.querySelector("[data-cancel]");if(cn)cn.onclick=()=>{setupFirst=null;entry="";render();};
}
function renderHomeScreenTip(){
  setAccent();
  root.innerHTML=`<div class="screen"><div class="auth">
    <div class="glyph">${ICON.cairn}</div>
    <h1>Add Cairn to your Home Screen</h1>
    <p>So it opens full-screen like a real app — and can send you reminders.</p>
    <ol class="hstip">
      <li>In Safari, tap the <b>Share</b> button (the square with an ↑ arrow).</li>
      <li>Scroll down and tap <b>Add to Home Screen</b>.</li>
      <li>Tap <b>Add</b>, then open Cairn from its new icon.</li>
    </ol>
    <button class="btn" id="hs-ok">Got it</button>
  </div></div>`;
  document.getElementById("hs-ok").onclick=()=>{markHomeTipSeen();showApp();};
}

function renderAuth(msg){
  authMode=authMode||"signin";setAccent();
  root.innerHTML=`<div class="screen"><div class="auth">
    <div class="glyph">${ICON.cairn}</div>
    <h1>Cairn</h1>
    <p>${msg?msg:(authMode==="signup"?"Request access to try Cairn — the owner approves new members.":"Sign in to your account.")}</p>
    <form id="a-form" autocomplete="on">
      ${authMode==="signup"?'<input id="a-name" autocomplete="name" placeholder="Your name" required>':''}
      <input id="a-email" type="email" inputmode="email" autocomplete="username" placeholder="Email" required>
      <input id="a-pass" type="password" autocomplete="${authMode==="signup"?"new-password":"current-password"}" placeholder="Password" required>
      <div class="err" id="a-err"></div>
      <button class="btn" id="a-btn" type="submit">${labelFor()}</button>
    </form>
    <button class="swap" id="a-swap">${authMode==="signup"?"Have an account? Sign in":"New here? Request access"}</button>
  </div></div>`;
  document.getElementById("a-form").onsubmit=(e)=>{e.preventDefault();
    const em=document.getElementById("a-email").value.trim();const pw=document.getElementById("a-pass").value;
    const nmEl=document.getElementById("a-name");const nm=nmEl?nmEl.value.trim():"";
    if(em&&pw)doAuth(em,pw,nm);};
  document.getElementById("a-swap").onclick=()=>{authMode=authMode==="signup"?"signin":"signup";renderAuth();};
}
function renderPending(){
  setAccent();const denied=access.status==="denied";
  root.innerHTML=`<div class="screen"><div class="auth">
    <div class="glyph">${ICON.lock}</div>
    <h1>${denied?"Not approved":"Waiting for approval"}</h1>
    <p>${denied?"The owner hasn't granted you access to Cairn.":"Your request was sent. You'll get in as soon as the owner approves you — check back shortly."}</p>
    ${denied?"":'<button class="btn" id="pg-check">Check again</button>'}
    <button class="swap" id="pg-out">Sign out</button>
  </div></div>`;
  const c=document.getElementById("pg-check");if(c)c.onclick=()=>enterApp();
  document.getElementById("pg-out").onclick=signOut;
}

let pendingTour=false;
function renderOnboard(){ // new user: blank page (named from signup), then the tour
  pendingTour=true;
  const p=presetEmpty();
  try{const nm=localStorage.getItem("cairn_name_"+userId);if(nm&&nm.trim())p.name=nm.trim();}catch(_){}
  onboard(p);
}
function tourSeen(){try{return localStorage.getItem("cairn_tour_"+userId)==="1";}catch(e){return false;}}
function markTourSeen(){try{localStorage.setItem("cairn_tour_"+userId,"1");}catch(e){}}

/* Spotlight product tour: drives the real app (switches tabs, scrolls) and dims
   everything except the element it's teaching, with a caption. Minimalist copy. */
function runTour(){
  const steps=[
    {tab:"today",   sel:null,                       t:"Cairn",              b:"Today, and nothing else. Here's the whole thing — thirty seconds."},
    {tab:"today",   sel:".ring",                    t:"Your day at a glance", b:"Completion, streak, and water — up top."},
    {tab:"today",   sel:".addbtn",                  t:"Add anything",        b:"Tap ＋ to add a task. Habit, chore, prayer, training."},
    {tab:"today",   sel:".rowwrap",                 t:"Swipe a task",        b:"Swipe right to edit it. Swipe left to delete — you get an undo."},
    {tab:"today",   sel:".rowwrap",                 t:"Hold to rearrange",   b:"Press and hold a task, then drag it anywhere in the list. It stays where you put it."},
    {tab:"today",   sel:'[data-act="restday"]',     t:"Rest is built in",    b:"Three rest days a week. Guilt-free — your streak holds."},
    {tab:"week",    sel:'.tab[data-tab="week"]',    t:"Your week",           b:"Every day's progress. Tap a past day to fix a missed check."},
    {tab:"history", sel:'.tab[data-tab="history"]', t:"Streaks & trends",    b:"Miss a day and it resets — unless you save it, once a month."},
    {tab:"settings",sel:'[data-act="manage"]',      t:"Manage tasks",        b:"Add, edit, reorder, archive, or remove — anytime."},
    {tab:"settings",sel:'[data-act="reminders"]',   t:"Reminders",           b:"Nudges at your task times, and a nightly summary."},
    {tab:"settings",sel:'[data-act="accent"]',      t:"Accent color",        b:"Twelve calm colors — make it yours."},
    {tab:"settings",sel:'[data-act="theme"]',       t:"Background & theme",  b:"Light, dark, or pure black for OLED."},
    {tab:"today",   sel:null,                       t:"Start with one",      b:"Add a single task. Little by little is how it holds."}
  ];
  if(!isStandalone()) steps.splice(steps.length-1,0,{tab:"today",sel:null,t:"Add to Home Screen",b:"In Safari: Share → Add to Home Screen. It opens full-screen and lets reminders reach you."});
  let i=0;
  const ov=document.createElement("div");ov.className="tourwrap";
  ov.innerHTML='<div class="tourbackdrop" id="tourbd"></div><div class="tourspot" id="tourspot"></div><div class="tourcap" id="tourcap"></div>';
  document.body.appendChild(ov);
  const spot=ov.querySelector("#tourspot"),cap=ov.querySelector("#tourcap"),bd=ov.querySelector("#tourbd");
  let focused=null,spotRect=null,capTop=null;spot.style.cssText="left:50%;top:50%;width:0;height:0";
  function finish(){if(focused)focused.classList.remove("tourfocus");ov.remove();tab="today";render();}
  function show(){
    if(focused)focused.classList.remove("tourfocus");focused=null;
    const st=steps[i];tab=st.tab;render();
    setTimeout(()=>{
      const el=st.sel?root.querySelector(st.sel):null;
      if(el)el.scrollIntoView({block:"center"});
      setTimeout(()=>place(el,st),el?90:0);
    },30);
  }
  function place(el,st){
    let r=null;
    if(el){r=el.getBoundingClientRect();const p=8;
      spot.style.opacity="1";bd.classList.remove("on");                    // crisp spotlight step
      const next={left:r.left-p,top:r.top-p,width:r.width+p*2,height:r.height+p*2};
      spot.style.left=next.left+"px";spot.style.top=next.top+"px";spot.style.width=next.width+"px";spot.style.height=next.height+"px";
      if(spotRect&&!prefersReduce())spot.animate([
        {transform:`translate(${spotRect.left-next.left}px,${spotRect.top-next.top}px) scale(${spotRect.width/next.width},${spotRect.height/next.height})`},
        {transform:"none"}],{duration:400,easing:"cubic-bezier(.25,.8,.2,1)"});
      spotRect=next;
      el.classList.add("tourfocus");focused=el;
    }else{spot.style.opacity="0";bd.classList.add("on");}                  // caption-only: blur the app behind
    const final=i===steps.length-1;
    cap.innerHTML=`${final?cairnHtml("tourcairn"):""}<div class="tc-num">${i+1} / ${steps.length}</div>
      <div class="tc-title">${st.t}</div><div class="tc-body">${st.b}</div>
      <div class="tc-dots">${steps.map((_,k)=>`<i class="${k===i?"on":""}"></i>`).join("")}</div>
      <div class="tc-row"><button class="swap" id="tc-skip">Skip</button><div style="flex:1"></div>
        ${i>0?'<button class="tc-btn" id="tc-back">Back</button>':""}
        <button class="tc-btn primary" id="tc-next">${i===steps.length-1?"Done":"Next"}</button></div>`;
    const capH=cap.offsetHeight,vh=window.innerHeight;let top;
    if(!el)top=Math.max(16,(vh-capH)/2);
    else{top=r.bottom+14;if(top+capH>vh-14)top=r.top-capH-14;if(top<14)top=14;}
    const oldTop=capTop;capTop=top;cap.style.top=top+"px";
    cap.className="tourcap"+(oldTop===null?" pop":"")+(i===0?" welcome":"")+(final?" final":"");
    if(oldTop!==null&&!prefersReduce())cap.animate([{transform:`translateY(${oldTop-top}px)`,opacity:.72},{transform:"none",opacity:1}],{duration:320,easing:"cubic-bezier(.22,.7,.3,1)"});
    cap.querySelector("#tc-next").onclick=()=>{ if(i<steps.length-1){i++;show();} else finish(); };
    cap.querySelector("#tc-skip").onclick=finish;
    const bk=cap.querySelector("#tc-back");if(bk)bk.onclick=()=>{i--;show();};
  }
  show();
}

let lastRenderedTab=null;
function render(){
  if(!state){renderAuth();return;}
  setAccent();
  const keepScroll = tab===lastRenderedTab;                 // same tab => don't jump to top
  const prev = keepScroll ? ((root.querySelector(".scroll")||{}).scrollTop||0) : 0;
  const tabs=["today","week","history","settings"],from=lastRenderedTab?tabs.indexOf(lastRenderedTab):-1,to=tabs.indexOf(tab);
  const dir=from<0?"":to>from?" dir-left":" dir-right";
  let body=tab==="today"?todayView():tab==="week"?weekView():tab==="history"?historyView():settingsView();
  root.innerHTML=`<div class="screen"><div class="scroll${keepScroll?"":" enter"}${keepScroll?"":dir}">${body}</div>${tabbar()}</div>`;
  const ns=root.querySelector(".scroll"); if(ns&&prev)ns.scrollTop=prev;
  bindApp();
  lastRenderedTab=tab;
  if(tab==="today"){animateRing();animateStreak();animateHydration();}
  if(tab==="settings")updateReminderLabel();
  if(tab==="history"&&!state.totalsLoaded)loadTotals();
  resolveLaunch();
}
/* Animate the completion ring fill + count the % up; celebrate at 100%. */
function animateRing(){
  const ring=root.querySelector(".ring");if(!ring)return;
  const target=+ring.dataset.pct||0, rest=ring.dataset.rest==="1", lbl=ring.querySelector(".lbl b");
  const from=ringLast,delay=ringWait;ringLast=target;ringWait=0;
  if(rest){ring.style.setProperty("--v",0);return;}
  if(prefersReduce()||Math.round(from)===Math.round(target)){
    ring.style.setProperty("--v",target);if(lbl)lbl.textContent=Math.round(target)+"%";
    if(target>=100&&from<100)ring.classList.add("complete");return;
  }
  const mark=[25,50,75,100].filter(x=>from<x&&target>=x).pop()||0;
  function run(){if(!ring.isConnected)return;const t0=performance.now(),dur=680;
  function step(now){const p=Math.min(1,(now-t0)/dur),e=1-Math.pow(1-p,3),v=from+(target-from)*e;
    ring.style.setProperty("--v",v);if(lbl)lbl.textContent=Math.round(v)+"%";
    if(p<1)requestAnimationFrame(step);
    else if(mark){ring.classList.add(mark===100?"complete":"milestone");celebrateBurst(mark);if(mark===100&&navigator.vibrate)navigator.vibrate([12,40,12]);}}
  requestAnimationFrame(step);}
  if(delay)setTimeout(run,delay);else run();
}
function celebrateBurst(mark=100){
  if(prefersReduce())return;
  const ring=root.querySelector(".ring");if(!ring)return;
  const r=ring.getBoundingClientRect(),cx=r.left+r.width/2,cy=r.top+r.height/2;
  const cs=getComputedStyle(document.documentElement);
  const colors=mark===100?["#b99654","#d6ba76","#8c713d"]:[(cs.getPropertyValue("--accent")||"#5b7089").trim(),"#a5834a"];
  const wrap=document.createElement("div"),n=mark===100?12:6;wrap.className="burst "+(mark===100?"full":"small");
  for(let k=0;k<n;k++){const dot=document.createElement("i");const ang=(k/n)*Math.PI*2,dist=(mark===100?34:23)+Math.random()*(mark===100?24:10);
    dot.style.left=cx+"px";dot.style.top=cy+"px";dot.style.background=colors[k%colors.length];
    dot.style.setProperty("--dx",(Math.cos(ang)*dist).toFixed(1)+"px");dot.style.setProperty("--dy",(Math.sin(ang)*dist).toFixed(1)+"px");
    wrap.appendChild(dot);}
  document.body.appendChild(wrap);setTimeout(()=>wrap.remove(),950);
}
function animateStreak(){
  const el=root.querySelector(".streaknum");if(!el)return;
  const target=+el.dataset.streak||0,from=streakLast;streakLast=target;
  if(from===null||target<=from||prefersReduce()){el.textContent=target;return;}
  el.innerHTML=`<i class="old">${from}</i><i class="new">${target}</i>`;el.classList.add("rolling");
  setTimeout(()=>{if(el.isConnected){el.classList.remove("rolling");el.textContent=target;}},420);
}
function animateHydration(){
  const hyd=root.querySelector(".hyd[data-pct]"),fill=hyd&&hyd.querySelector(".bar i");if(!fill)return;
  const target=+hyd.dataset.pct||0,from=waterLast;waterLast=target;
  fill.style.transform=`scaleX(${target/100})`;
  if(from!==null&&target!==from&&!prefersReduce())fill.animate([{transform:`scaleX(${from/100})`},{transform:`scaleX(${target/100})`}],{duration:620,easing:"cubic-bezier(.2,.8,.25,1)"});
}

/* ---------- Today ---------- */
function todayView(){
  const t=todayStr(),{done,total,frac}=dayFraction(t),pct=Math.round(frac*100),streak=currentStreak();
  const rest=isRestDay(t);
  const summary=total===0?"The day is open.":done===total?"The path is clear.":frac>=.75?"Close the loop.":frac>=.4?"The day is taking shape.":"Set the first stone.";
  const due=dueTasks(t);rowStagger=0;
  const doneItems=due.filter(x=>statusOf(t,x.id)==="done");
  const pending=due.filter(x=>statusOf(t,x.id)!=="done");
  const water=hydOz(t),waterPct=Math.min(100,Math.round(water/state.goalOz*100));
  const keys=due.filter(x=>x.keystone),allDone=due.length&&due.every(x=>statusOf(t,x.id)==="done");
  const coreDone=keys.length&&!allDone&&keys.every(x=>statusOf(t,x.id)==="done");
  let groups="",gi=0;
  for(const g of GROUPS){const items=pending.filter(x=>x.group===g.k).sort(bySort);if(!items.length)continue;
    groups+=`<div class="pathgroup" style="--group-i:${gi++}"><div class="grouphead"><span class="pathnode"></span><span class="ghname">${g.t}</span><span class="n">${items.length} ${items.length===1?"marker":"markers"}</span></div><div class="card pathcard" data-group="${g.k}">${items.map(rowHtml).join("")}</div></div>`;}
  const hyTask=due.find(x=>x.hydration);
  const completed=doneItems.length?`<section class="completedblock"><div class="sectionhead compact"><div><span>Placed today</span><h3>${doneItems.length} ${doneItems.length===1?"stone":"stones"}</h3></div><span class="sectioncount">${done}/${total}</span></div><div class="card completedcard">${doneItems.sort(bySort).map(rowHtml).join("")}</div></section>`:"";
  const av=(state.name||"?").trim().charAt(0).toUpperCase();
  return `<section class="daystone ${rest?"resting":""} ${allDone?"complete":""}">
    <div class="daytop"><div class="daytitle"><span class="daylabel">Today</span><h1>${prettyDate(t)}</h1>
      <div class="daystatus"><span id="syncdot" class="syncdot${syncOn?"":" off"}"></span>${syncOn?"Synced":"Offline"}<i></i>Mountain · ${tzAbbr()}</div></div>
    <div class="dayactions">
      <button class="addbtn" data-act="add-task" aria-label="Add task">＋</button>
      <button class="who" data-act="go-settings" aria-label="Open settings for ${escapeAttr(state.name)}"><span class="av">${av}</span></button>
    </div></div>
    <div class="daycore"><div class="ring" data-pct="${rest?0:pct}" data-rest="${rest?1:0}" style="--v:${rest?0:ringLast}"><div class="lbl"><b>${rest?'🌙':ringLast+'%'}</b><span>${rest?'rest':'placed'}</span></div></div>
      <div class="daymessage"><span>${rest?"REST DAY":allDone?"DAY HELD":total===0?"OPEN DAY":"TODAY'S PATH"}</span><h2>${rest?"Rest without losing ground.":summary}</h2>
        <p>${rest?"Your streak stays protected.":total?`${done} of ${total} markers placed.`:"Add one thing worth keeping."}</p></div></div>
    <div class="daystats">
      <div class="daystat ${justCompletedId?"changed":""}"><span>Progress</span><strong>${done}<small> / ${total}</small></strong></div>
      <div class="daystat"><span>Streak</span><strong><b class="streaknum" data-streak="${streak}">${streak}</b><small> days</small></strong></div>
      <div class="daystat"><span>Water</span><strong>${waterPct}<small>%</small></strong></div>
    </div>
    <div class="daycontrols"><button class="restcontrol ${rest?'on':''}" data-act="restday"><span class="restmoon">${rest?'☀':'◐'}</span><span><b>${rest?'Resume today':'Rest day'}</b><small>${rest?'Return to the path':'Protect the streak'}</small></span></button>
      ${coreDone?'<span class="corebadge"><i>✓</i> Core held</span>':""}
      ${canSaveStreak()?`<button class="savecontrol" data-act="savestreak">Save streak</button>`:""}
    </div>
  </section>
  ${partnerCard()}
  ${hyTask?`<section class="rhythmblock">${hydCard()}</section>`:""}
  <section class="pathsection"><div class="sectionhead"><div><span>The path</span><h3>${pending.length?`${pending.length} ${pending.length===1?"marker remains":"markers remain"}`:"Nothing left unfinished"}</h3></div><span class="sectioncount">${pct}%</span></div>
    ${groups||(total===0?emptyToday():'<div class="pathclear"><span>✓</span><div><b>The path is clear.</b><small>Everything asked of today is held.</small></div></div>')}
  </section>
  ${completed}
  ${noteCard()}
  <div class="todayfoot">${ICON.cairn}<span>Little by little is how it holds.</span></div>`;
}
function emptyToday(){
  const starters=[["Drink water","drop",1],["Workout","dumbbell",0],["Read","book",0],["Sleep","moon",0],["Pray","hands",0]];
  return `<div class="empty">Nothing here yet.<br>Tap <b>＋</b> up top to add your first task.
    <div class="starters">${starters.map(([t,s,h])=>`<button class="chip starter" data-act="starter" data-starter="${escapeAttr(t)}" data-sym="${s}" data-hyd="${h}">${symChar(s)} ${t}</button>`).join("")}</div></div>`;
}
/* Your own order wins — time is only a reminder, never a sort key. */
function bySort(a,b){return (a.sort_index||0)-(b.sort_index||0);}
function byTime(a,b){const ta=a.time||"99:99",tb=b.time||"99:99";return ta<tb?-1:ta>tb?1:0;}
function rowHtml(t){const done=statusOf(todayStr(),t.id)==="done",ri=rowStagger++;const subs=[];
  if(t.time)subs.push(fmt12(t.time));if(t.hydration)subs.push(`${hydOz(todayStr())} / ${state.goalOz} oz`);
  if(t.measureUnit)subs.push(`${valueFor(t.id,todayStr())} ${escapeHtml(t.measureUnit)}`);
  const overdue=!done && t.time && hmToMin(t.time)!==null && hmToMin(t.time) < nowMinutes();
  if(overdue)subs.push('<span style="color:var(--warn);font-weight:600">overdue</span>');
  return `<div class="rowwrap ${t.id===justAddedId?"justadd":""}" data-rid="${t.id}" style="--row-i:${ri}">
    <div class="rowacts"><div class="ract edit">${ICON.pencil}</div><div class="ract del">${ICON.trash}</div></div>
    <div class="row tap ${done?"done":""} ${t.id===justCompletedId?"justdone":""}" data-act="${t.measureUnit?"measure":"toggle"}" data-id="${t.id}">
    <div class="check">${ICON.check}</div>
    <div class="rowmain"><div class="t">${t.keystone?'<span class="corepin" title="Non-negotiable">●</span> ':''}${escapeHtml(t.title)}</div>${subs.length?`<div class="sub">${subs.join(" · ")}</div>`:""}</div>
    ${t.appUrl?`<button class="openapp" data-act="openapp" data-url="${escapeAttr(t.appUrl)}" aria-label="Open app">↗</button>`:""}
    ${t.pri&&!done?'<span class="pri">!</span>':""}<div class="rowsym">${symChar(t.sym)}</div></div></div>`;}
function hydCard(){const o=hydOz(todayStr()),g=state.goalOz,pct=Math.min(100,Math.round(o/g*100));
  return `<div class="hyd ${waterPulse?"pour":""}" data-pct="${pct}"><div class="hydhead"><span class="hydicon">💧</span><div><span>Daily rhythm</span><b>Hydration</b></div><div class="hydtotal"><strong>${o}</strong><small> / ${g} oz</small></div></div>
    <div class="bar"><i></i><em></em></div>
    <div class="hydfoot"><span>${pct>=100?"Goal held.":`${Math.max(0,g-o)} oz remain`}</span><div class="adds">${[8,16,20,24].map(n=>`<button data-act="water" data-oz="${n}">+${n}</button>`).join("")}
    <button class="more" data-act="water-custom">＋</button></div></div></div>`;}

/* ---------- Grace + couple helpers ---------- */
function toggleRestDay(){
  const t=todayStr();if(!Array.isArray(state.restDays))state.restDays=[];
  const isRest=state.restDays.includes(t);
  if(!isRest){ // enforce max 3 rest days per (Sun–Sat) week
    const start=addDays(t,-weekdayOf(t)),end=addDays(start,6);
    if(state.restDays.filter(d=>d>=start&&d<=end).length>=3){alert("You've used all 3 rest days this week.");return;}
  }
  state.restDays=isRest?state.restDays.filter(d=>d!==t):[...state.restDays,t];
  mSaveProfile();
}
function partnerCard(){
  if(!state.partnerId)return "";
  const ps=state.partnerStatus,name=escapeHtml(state.partnerName||"Your partner");
  const av=(state.partnerName||"?").trim().charAt(0).toUpperCase();
  let line;
  if(!ps||ps.total===0)line="No update yet today";
  else if(ps.all_done)line="Finished their day 🎉";
  else line=`${ps.done} of ${ps.total} done today`;
  return `<div class="partnercard"><span class="pav">${av}</span>
      <div class="pmain"><span>Together</span><b>${name}</b><small>${line}</small></div><span class="pheart">♥</span></div>`;
}

function noteCard(){
  const n=noteFor(todayStr());
  return `<section class="journalblock"><div class="sectionhead"><div><span>Daily reflection</span><h3>What held today together?</h3></div><span class="journalmark">✎</span></div>
    <div class="notecard tap ${n?"written":""}" data-act="editnote"><span class="journalentry">${n?escapeHtml(n):'<span class="ph">Leave one honest line about the day.</span>'}</span><span class="journalcta">${n?"Edit reflection":"Write today’s line"} <i>›</i></span></div></section>`;
}
function editNoteSheet(){
  const t=todayStr(),cur=noteFor(t);
  const s=openSheet(`<span class="sheeteyebrow">Daily reflection</span><h3>${prettyDate(t)}</h3>
    <div class="field"><label>What held today together?</label>
      <textarea id="n-txt" rows="5">${escapeHtml(cur)}</textarea></div>
    <button class="btn" id="n-save">Save</button>`);
  s.bg.querySelector("#n-save").onclick=()=>{setNote(t,s.bg.querySelector("#n-txt").value.trim());s.close();};
}

/* ---------- Week ---------- */
function weekView(){const t=todayStr(),dow=weekdayOf(t),start=addDays(t,-dow);let rows="";
  for(let i=0;i<7;i++){const ymd=addDays(start,i),f=dayFraction(ymd),pct=Math.round(f.frac*100),future=ymd>t,isT=ymd===t;
    const hy=hydOz(ymd),hyPct=Math.min(100,Math.round(hy/state.goalOz*100));const trading=dueTasks(ymd).some(x=>x.group==="trading");
    rows+=`<div class="weekrow${future?"":" tap"}" ${future?"":`data-act="editday" data-ymd="${ymd}"`}>
      <div class="wd ${isT?"today":""}"><div class="dn">${WD_SHORT[weekdayOf(ymd)]}</div><div class="dd">${ymd.slice(-2)}</div></div>
      <div class="wmeta"><div>${future?'<span style="color:var(--faint)">—</span>':`${f.done}/${f.total} done`}${trading?" · 📈":""}${isProtected(ymd)?" · 🌙":""}</div>
      <div class="b2"><i style="width:${future?0:pct}%"></i></div>${hy>0?`<div style="font-size:11px;color:var(--faint);margin-top:4px">💧 ${hy} oz (${hyPct}%)</div>`:""}</div>
      <div class="wpct">${future?"":pct+"%"}</div></div>`;}
  return `<div class="h2">This Week</div><div class="tzrow pad" style="margin:-2px 0 10px">${prettyMonthRange(start)} · tap a day to fix a missed check</div>
    <div class="card" style="margin:0 16px;padding:2px 0">${rows}</div>`;}
/* Backfill: edit a past day's completions (for days you forgot to check off). */
function dayBackfillSheet(ymd){
  const due=dueTasks(ymd);
  const rows=due.length?due.map(tk=>{const done=statusOf(ymd,tk.id)==="done";
    return `<div class="mrow"><div class="rowsym">${symChar(tk.sym)}</div><div class="t">${escapeHtml(tk.title)}</div>
      <button class="chip ${done?"on":""}" data-back="${tk.id}">${done?"✓ Done":"Mark done"}</button></div>`;}).join(""):'<div class="empty">Nothing was scheduled.</div>';
  const s=openSheet(`<h3>${prettyDate(ymd)}</h3><p class="note" style="margin-bottom:6px">Fix a day you forgot to check off.</p>${rows}`);
  s.bg.querySelectorAll("[data-back]").forEach(b=>b.onclick=()=>{
    const id=b.dataset.back,nowDone=statusOf(ymd,id)==="done";
    mSetStatus(id,ymd,nowDone?null:"done");
    b.classList.toggle("on",!nowDone);b.textContent=!nowDone?"✓ Done":"Mark done";
  });
}
function prettyMonthRange(start){const a=ymdToUTC(start),b=ymdToUTC(addDays(start,6));
  const f=d=>d.toLocaleDateString("en-US",{month:"short",day:"numeric",timeZone:"UTC"});return `${f(a)} – ${f(b)}`;}

/* ---------- History ---------- */
function historyView(){const t=todayStr();let cells="",schedTot=0,doneTot=0;
  for(let i=29;i>=0;i--){const ymd=addDays(t,-i),f=dayFraction(ymd);schedTot+=f.total;doneTot+=f.done;
    cells+=`<div class="cell" style="background:${f.total?`color-mix(in srgb,var(--accent) ${Math.round(f.frac*100)}%, var(--ring-track))`:"var(--ring-track)"}" title="${ymd}: ${Math.round(f.frac*100)}%">${ymd.slice(-2)}</div>`;}
  const rate=schedTot?Math.round(doneTot/schedTot*100):0;
  const taskRows=state.tasks.map(tk=>`<div class="weekrow"><div class="rowsym">${symChar(tk.sym)}</div>
    <div class="wmeta" style="flex:1"><div style="font-size:15px">${escapeHtml(tk.title)}</div></div>
    <div style="text-align:right"><div style="font-weight:650" class="tnum">${taskStreak(tk)}</div><div style="font-size:11px;color:var(--faint)">day streak</div></div></div>`).join("");
  return `<div class="h2">History</div>
    <div class="statwrap"><div class="stat"><b class="tnum">${currentStreak()}</b><span>Current streak</span></div>
      <div class="stat"><b class="tnum">${longestStreak()}</b><span>Longest</span></div>
      <div class="stat"><b class="tnum">${rate}%</b><span>30-day rate</span></div></div>
    ${weeklyReview()}
    <div class="grouphead">Last 30 days</div><div class="grid30">${cells}</div>
    <div class="grouphead">Per-task streaks</div><div class="card" style="margin:0 16px;padding:2px 0">${taskRows||'<div class="empty">No tasks yet.</div>'}</div>
    ${(()=>{const measured=state.tasks.filter(x=>x.measureUnit&&!x.archived);if(!measured.length)return "";
      return `<div class="grouphead">Trends · last 7 days</div>`+measured.map(tk=>{
        const vals=[];for(let i=6;i>=0;i--)vals.push(valueFor(tk.id,addDays(t,-i)));
        const mx=Math.max(1,...vals);
        const bars=vals.map(v=>`<div class="tbar" style="height:${v>0?Math.max(6,Math.round(v/mx*100)):2}%" title="${v}"></div>`).join("");
        return `<div class="trendrow"><div class="trendhead"><span>${symChar(tk.sym)} ${escapeHtml(tk.title)}</span><b class="tnum">${vals[6]} ${escapeHtml(tk.measureUnit)}</b></div><div class="tbars">${bars}</div></div>`;
      }).join("");})()}
    ${state.totals?`<div class="grouphead">All time</div><div class="statwrap">
      <div class="stat"><b class="tnum">${state.totals.done.toLocaleString()}</b><span>tasks done</span></div>
      <div class="stat"><b class="tnum">${state.totals.oz.toLocaleString()}</b><span>oz of water</span></div></div>`:""}
    <div style="height:8px"></div>`;}

/* A gentle Sunday-style summary of the last 7 days + one focus. */
function weeklyReview(){
  const t=todayStr();let sched=0,done=0;const per={};
  for(let i=0;i<7;i++){const ymd=addDays(t,-i);if(isProtected(ymd))continue;
    for(const tk of dueTasks(ymd)){sched++;const ok=statusOf(ymd,tk.id)==="done";if(ok)done++;
      (per[tk.id]=per[tk.id]||{title:tk.title,d:0,n:0}).n++;if(ok)per[tk.id].d++;}}
  if(sched===0)return "";
  const pct=Math.round(done/sched*100),arr=Object.values(per).filter(x=>x.n>=2);
  const worst=arr.slice().sort((a,b)=>(a.d/a.n)-(b.d/b.n))[0];
  const best=arr.slice().sort((a,b)=>(b.d/b.n)-(a.d/a.n))[0];
  const focus=(worst&&worst.d/worst.n<1)?`Focus: <b>${escapeHtml(worst.title)}</b> — ${worst.d}/${worst.n} this week.`:`Strong week — keep the momentum.`;
  return `<div class="grouphead">This week</div>
    <div class="reviewcard">
      <div class="rtop"><b class="tnum">${pct}%</b><span>of scheduled tasks done, last 7 days</span></div>
      ${best&&best.d===best.n&&best.n>=3?`<div class="rline">✅ Perfect on <b>${escapeHtml(best.title)}</b></div>`:""}
      <div class="rline">🎯 ${focus}</div>
    </div>`;
}
/* Full JSON backup — pulls all history from the server so you own your data. */
async function exportData(){
  try{
    const [c,h]=await Promise.all([
      SB.from("completions").select("task_id,day,status"),
      SB.from("hydration").select("day,oz")
    ]);
    const payload={app:"Cairn",version:1,exportedAt:new Date().toISOString(),timeZone:TZ,
      profile:{name:state.name,accent:state.accent,goalOz:state.goalOz},
      tasks:state.tasks,restDays:state.restDays||[],savedDays:state.savedDays||[],
      completions:c.data||[],hydration:h.data||[]};
    const blob=new Blob([JSON.stringify(payload,null,2)],{type:"application/json"});
    const url=URL.createObjectURL(blob);
    const a=document.createElement("a");a.href=url;a.download=`cairn-backup-${todayStr()}.json`;
    document.body.appendChild(a);a.click();a.remove();
    setTimeout(()=>URL.revokeObjectURL(url),2000);
  }catch(e){alert("Couldn't export: "+(e&&e.message||e));}
}

/* ---------- Settings ---------- */
function settingsView(){
  return `<div class="h2">Settings</div><div class="pad">
    <div class="setrow" data-act="manage"><span>Manage tasks</span><span class="r">${state.tasks.length} ›</span></div>
    <div class="setrow" data-act="goal"><span>Hydration goal</span><span class="r">${state.goalOz} oz ›</span></div>
    <div class="setrow" data-act="accent"><span>Accent color</span><span class="r"><span style="width:16px;height:16px;border-radius:50%;background:var(--accent);display:inline-block"></span> ›</span></div>
    <div class="setrow" data-act="theme"><span>Appearance</span><span class="r" id="themeLbl">${themeLabel()} ›</span></div>
    <div class="setrow" data-act="rename"><span>Profile name</span><span class="r">${escapeHtml(state.name)} ›</span></div>
    <div class="setrow" data-act="tutorial"><span>See the tutorial again</span><span class="r">Replay ›</span></div>
    <div class="setrow" data-act="changecode"><span>Change unlock code</span><span class="r">${ICON.lock}</span></div>
    <div class="setrow" data-act="reminders"><span>Reminders</span><span class="r" id="remVal">…</span></div>
    <div class="setrow" data-act="summarytime"><span>Nightly summary time</span><span class="r">${fmt12(state.summaryTime||"21:30")} ›</span></div>
    <div class="setrow" data-act="quiethours"><span>Quiet hours</span><span class="r">${state.quietStart&&state.quietEnd?fmt12(state.quietStart)+"–"+fmt12(state.quietEnd):"Off"} ›</span></div>
    <div class="setrow" data-act="partner"><span>Partner</span><span class="r">${state.partnerId?escapeHtml(state.partnerName||"Linked")+" 💞":"Not linked"} ›</span></div>
    ${access.isAdmin?`<div class="setrow" data-act="members"><span>Members <span style="color:var(--accent);font-size:12px">· admin</span></span><span class="r">Manage ›</span></div>`:""}
    <div style="height:22px"></div>
    <button class="btn ghost" data-act="add-task">＋ Add a task</button>
    <div style="height:10px"></div>
    <button class="btn ghost" data-act="export" style="margin-bottom:10px">Export my data (JSON backup)</button>
    <button class="btn danger" data-act="signout">Sign out</button>
    <p class="note"><span class="syncdot${syncOn?"":" off"}"></span>${syncOn?"Synced to your account — changes appear on all your signed-in devices.":"Offline — changes are saved on this device and will sync when you're back online."} Signed in as ${escapeHtml(session?.user?.email||"")}.</p>
  </div>`;}

function tabbar(){const T=[["today","Today"],["week","Week"],["history","History"],["settings","Settings"]];
  const now=T.findIndex(x=>x[0]===tab),prev=Math.max(0,T.findIndex(x=>x[0]===lastRenderedTab)),moving=lastRenderedTab&&lastRenderedTab!==tab;
  return `<div class="tabs${moving?" moving":""}" style="--tab-x:${now*100}%;--tab-from-x:${prev*100}%">${T.map(([k,l])=>`<button class="tab ${tab===k?"on":""}" data-tab="${k}">${ICON[k]}<span>${l}</span></button>`).join("")}</div>`;}

/* =====================================================================
   EVENTS
===================================================================== */
function bindApp(){
  root.querySelectorAll("[data-tab]").forEach(b=>b.onclick=()=>{tab=b.dataset.tab;render();});
  root.querySelectorAll("[data-act]").forEach(el=>el.onclick=(e)=>handle(el.dataset.act,el,e));
  bindRowGestures();
  // Auto-hide the bottom tab bar: slide it away when scrolling down, reveal on scroll up.
  const sc=root.querySelector(".scroll");
  if(sc){
    let last=sc.scrollTop;
    sc.addEventListener("scroll",()=>{
      const tabs=root.querySelector(".tabs");if(!tabs)return;
      const cur=sc.scrollTop;
      if(cur>last+5 && cur>64) tabs.classList.add("hidden");        // scrolling down
      else if(cur<last-5 || cur<24) tabs.classList.remove("hidden"); // scrolling up / near top
      last=cur;
    },{passive:true});
  }
}
/* ---------- Row gestures: swipe (edit / delete) + hold-and-drag reorder ---------- */
let suppressClick=false;
function bindRowGestures(){
  root.querySelectorAll(".rowwrap").forEach(wrap=>{
    const row=wrap.querySelector(".row");if(!row)return;
    let sx=0,sy=0,mode="",lp=null,ctx=null,pid=null;
    const ACT=78;
    function startDrag(){
      mode="drag";suppressClick=true;
      try{const sel=window.getSelection&&window.getSelection();if(sel&&sel.removeAllRanges)sel.removeAllRanges();}catch(_){}
      document.body.classList.add("dragging-row");
      if(navigator.vibrate)navigator.vibrate(14);
      try{if(pid!==null)wrap.setPointerCapture(pid);}catch(_){}
      const card=wrap.parentElement,items=[...card.querySelectorAll(".rowwrap")];
      ctx={items,idx:items.indexOf(wrap),h:wrap.getBoundingClientRect().height,target:items.indexOf(wrap)};
      wrap.classList.add("dragging");
      items.forEach(it=>{if(it!==wrap)it.classList.add("shiftable");});
    }
    function dragMove(e){
      if(!ctx)return;
      ctx.px=e.clientX;ctx.py=e.clientY;
      const dy=e.clientY-sy;
      wrap.style.transform=`translateY(${dy}px)`;
      let tgt=Math.max(0,Math.min(ctx.items.length-1,ctx.idx+Math.round(dy/ctx.h)));
      ctx.target=tgt;
      ctx.items.forEach((it,i)=>{
        if(it===wrap)return;let sh=0;
        if(ctx.idx<tgt&&i>ctx.idx&&i<=tgt)sh=-ctx.h;
        else if(ctx.idx>tgt&&i<ctx.idx&&i>=tgt)sh=ctx.h;
        it.style.transform=sh?`translateY(${sh}px)`:"";
      });
    }
    function endDrag(e){
      document.body.classList.remove("dragging-row");
      if(!ctx)return;
      const px=(e&&e.clientX!=null)?e.clientX:ctx.px, py=(e&&e.clientY!=null)?e.clientY:ctx.py;
      /* Resolve the drop while the dragged row is hidden from hit-testing, so we see
         the card underneath. Dropping on another group's card re-homes the task. */
      let g=null,beforeId=null;
      if(px!=null&&py!=null){
        try{
          wrap.style.pointerEvents="none";
          const under=document.elementFromPoint(px,py);
          wrap.style.pointerEvents="";
          const card=(under&&under.closest)?under.closest(".card[data-group]"):null;
          if(card){
            g=card.dataset.group;
            const rows=[...card.querySelectorAll(".rowwrap[data-rid]")].filter(el=>el.dataset.rid!==wrap.dataset.rid);
            for(const el of rows){const r=el.getBoundingClientRect();if(py<r.top+r.height/2){beforeId=el.dataset.rid;break;}}
          }
        }catch(_){wrap.style.pointerEvents="";}
      }
      const {items,idx,target}=ctx;ctx=null;
      wrap.classList.remove("dragging");
      items.forEach(it=>{it.style.transform="";it.classList.remove("shiftable");});
      setTimeout(()=>suppressClick=false,300);
      if(g)dropTask(wrap.dataset.rid,g,beforeId);
      else if(idx!==target)commitReorder(items.map(it=>it.dataset.rid),idx,target);
      if((g||idx!==target)&&navigator.vibrate)navigator.vibrate(8);
    }
    wrap.addEventListener("pointerdown",e=>{
      if(e.button&&e.button!==0)return;
      sx=e.clientX;sy=e.clientY;mode="";pid=e.pointerId;
      row.classList.add("swiping");
      lp=setTimeout(()=>{if(mode==="")startDrag();},420);
    });
    wrap.addEventListener("pointermove",e=>{
      const dx=e.clientX-sx,dy=e.clientY-sy;
      if(mode===""){
        if(Math.abs(dx)>10&&Math.abs(dx)>Math.abs(dy)){mode="swipe";clearTimeout(lp);try{wrap.setPointerCapture(e.pointerId);}catch(_){}}
        else if(Math.abs(dy)>10){mode="scroll";clearTimeout(lp);row.classList.remove("swiping");}
      }
      if(mode==="swipe"){e.preventDefault();
        const c=Math.max(-118,Math.min(118,dx));
        row.style.transform=`translateX(${c}px)`;
        wrap.classList.toggle("sw-r",c>14);wrap.classList.toggle("sw-l",c<-14);
        wrap.classList.toggle("armed",Math.abs(c)>=ACT);
      }else if(mode==="drag"){e.preventDefault();dragMove(e);}
    });
    const finish=e=>{
      clearTimeout(lp);
      if(mode==="swipe"){
        const dx=(e.clientX||sx)-sx;
        row.classList.remove("swiping");row.style.transform="";
        wrap.classList.remove("sw-r","sw-l","armed");
        suppressClick=true;setTimeout(()=>suppressClick=false,320);
        const id=wrap.dataset.rid;
        if(dx>ACT){const t=state.tasks.find(x=>x.id===id);if(t)setTimeout(()=>editSheet(t),140);}
        else if(dx<-ACT)setTimeout(()=>mDeleteWithUndo(id),140);
      }else if(mode==="drag")endDrag(e);
      else row.classList.remove("swiping");
      mode="";
    };
    wrap.addEventListener("pointerup",finish);
    wrap.addEventListener("pointercancel",finish);
    wrap.addEventListener("contextmenu",e=>e.preventDefault());          // no long-press callout
    wrap.addEventListener("selectstart",e=>{if(mode)e.preventDefault();}); // no text highlight mid-gesture
    /* On touch, `touch-action:pan-y` lets Safari start scrolling the moment the finger moves
       vertically — which cancels the pointer and kills the drag. Because the finger is held
       still through the long-press, this first touchmove is still cancelable, so preventing it
       stops the scroll from ever starting and the drag survives. */
    wrap.addEventListener("touchmove",e=>{
      if((mode==="drag"||mode==="swipe")&&e.cancelable)e.preventDefault();
    },{passive:false});
  });
}
/* Drop a task into a group at a position — the group you drop it in becomes its category.
   Time stays a reminder only; your manual order is what the list follows. */
function dropTask(id,group,beforeId){
  const t=state.tasks.find(x=>x.id===id);if(!t)return;
  const first=(tab==="today")?captureRows():null;
  t.group=group;
  const rest=state.tasks.filter(x=>!x.archived&&x.id!==id).sort(bySort);
  const at=beforeId?rest.findIndex(x=>x.id===beforeId):-1;
  if(at>=0)rest.splice(at,0,t);else rest.push(t);
  rest.forEach((x,i)=>x.sort_index=i);
  cacheSave();render();playFlip(first);
  for(const x of rest)push(()=>SB.from("tasks").upsert(taskToRow(x,x.sort_index)));
}
/* Move a task within its group and re-flow global sort_index. */
function commitReorder(ids,from,to){
  const moved=ids[from],newIds=ids.slice();
  newIds.splice(from,1);newIds.splice(to,0,moved);
  const all=state.tasks.filter(t=>!t.archived).sort((a,b)=>(a.sort_index||0)-(b.sort_index||0));
  const slots=[];all.forEach((t,i)=>{if(ids.includes(t.id))slots.push(i);});
  newIds.forEach((id,k)=>{const t=state.tasks.find(x=>x.id===id);if(t)t.__s=slots[k];});
  all.forEach((t,i)=>{if(!ids.includes(t.id))t.__s=i;});
  all.sort((a,b)=>a.__s-b.__s).forEach((t,i)=>{t.sort_index=i;delete t.__s;});
  cacheSave();render();
  for(const t of all)push(()=>SB.from("tasks").upsert(taskToRow(t,t.sort_index)));
}
function handle(act,el,e){
  if(suppressClick&&(act==="toggle"||act==="measure"))return;   // a swipe/drag just happened
  if(act==="openapp"){if(e)e.stopPropagation();const u=el.dataset.url;if(u)window.open(u,"_blank");return;}
  if(act==="savestreak"){saveStreak();return;}
  if(act==="editday"){dayBackfillSheet(el.dataset.ymd);return;}
  if(act==="measure"){const tk=state.tasks.find(x=>x.id===el.dataset.id);const cur=valueFor(el.dataset.id,todayStr());
    const v=prompt(`How many ${tk?tk.measureUnit:""}?`,cur||"");if(v!==null&&v!=="")mSetValue(el.dataset.id,todayStr(),parseFloat(v));return;}
  if(act==="toggle"){const id=el.dataset.id,t=todayStr();mSetStatus(id,t,statusOf(t,id)==="done"?null:"done");if(navigator.vibrate)navigator.vibrate(8);}
  else if(act==="water")mAddWater(+el.dataset.oz);
  else if(act==="water-custom"){const n=parseFloat(prompt("Add how many ounces?"));if(n>0)mAddWater(n);}
  else if(act==="go-settings"){tab="settings";render();}
  else if(act==="manage")manageSheet();
  else if(act==="add-task")editSheet(null);
  else if(act==="starter")quickAdd(el.dataset.starter,el.dataset.sym,el.dataset.hyd==="1");
  else if(act==="goal"){const n=parseInt(prompt("Daily hydration goal (oz):",state.goalOz));if(n>0){state.goalOz=n;mSaveProfile();}}
  else if(act==="rename"){const v=prompt("Profile name:",state.name);if(v&&v.trim()){state.name=v.trim();mSaveProfile();}}
  else if(act==="accent")accentSheet();
  else if(act==="theme")themeSheet();
  else if(act==="changecode"){setupFirst=null;entry="";renderLockSetup(false);}
  else if(act==="export")exportData();
  else if(act==="tutorial")runTour();
  else if(act==="editnote")editNoteSheet();
  else if(act==="summarytime"){const v=prompt("Nightly summary time (24-hour, e.g. 21:30):",state.summaryTime||"21:30");
    if(v&&/^\d{1,2}:\d{2}$/.test(v.trim())){state.summaryTime=v.trim();render();
      push(()=>SB.from("reminder_settings").upsert({user_id:userId,summary_time:v.trim(),updated_at:new Date().toISOString()},{onConflict:"user_id"}));}}
  else if(act==="quiethours"){
    const st=prompt("Quiet hours START (24-hour, e.g. 22:00). Leave blank to turn off:",state.quietStart||"");
    if(st===null)return;
    if(!st.trim()){state.quietStart="";state.quietEnd="";render();
      push(()=>SB.from("reminder_settings").upsert({user_id:userId,quiet_start:null,quiet_end:null,updated_at:new Date().toISOString()},{onConflict:"user_id"}));return;}
    const en=prompt("Quiet hours END (24-hour, e.g. 07:00):",state.quietEnd||"07:00");
    if(en===null)return;
    if(/^\d{1,2}:\d{2}$/.test(st.trim())&&/^\d{1,2}:\d{2}$/.test(en.trim())){
      state.quietStart=st.trim();state.quietEnd=en.trim();render();
      push(()=>SB.from("reminder_settings").upsert({user_id:userId,quiet_start:st.trim(),quiet_end:en.trim(),updated_at:new Date().toISOString()},{onConflict:"user_id"}));}}
  else if(act==="reminders"){(async()=>{ if(await remindersOn())disableReminders(); else enableReminders(); })();}
  else if(act==="restday")toggleRestDay();
  else if(act==="partner")partnerSheet();
  else if(act==="members")membersSheet();
  else if(act==="signout"){if(confirm("Sign out of Cairn on this device?"))signOut();}
}
function setTheme(val){ // 'system' | 'light' | 'dark' | 'oled'
  const root=document.documentElement;
  if(val==="system"){root.removeAttribute("data-theme");try{localStorage.removeItem("cairn_theme");}catch(e){}}
  else{root.setAttribute("data-theme",val);try{localStorage.setItem("cairn_theme",val);}catch(e){}}
  updateThemeMeta();
}
function updateThemeMeta(){
  const t=document.documentElement.getAttribute("data-theme");
  const dark = t==="dark" || t==="oled" || (!t && window.matchMedia && window.matchMedia("(prefers-color-scheme:dark)").matches);
  const color = t==="oled" ? "#000000" : (dark ? "#141513" : "#f5f4f1");
  let m=document.getElementById("theme-color-managed");
  if(!m){m=document.createElement("meta");m.id="theme-color-managed";m.name="theme-color";document.head.appendChild(m);}
  m.setAttribute("content",color);
}
function themeLabel(){const t=document.documentElement.getAttribute("data-theme");
  return t==="oled"?"Pure Black":t?t[0].toUpperCase()+t.slice(1):"System";}
function themeSheet(){
  const cur=document.documentElement.getAttribute("data-theme")||"system";
  const opts=[["system","System"],["light","Light"],["dark","Dark"],["oled","Pure Black · OLED"]];
  const s=openSheet(`<h3>Appearance</h3><div class="picker">${opts.map(([v,l])=>`<button data-th="${v}" class="${cur===v?"on":""}">${l}</button>`).join("")}</div>`);
  s.bg.querySelectorAll("[data-th]").forEach(b=>b.onclick=()=>{setTheme(b.dataset.th);s.close();render();});
}

/* ---------- Sheets ---------- */
function openSheet(html){
  const bg=document.createElement("div");bg.className="sheet-bg";
  bg.innerHTML=`<div class="sheet"><div class="grab" aria-label="Drag down to close"></div>${html}</div>`;
  document.body.appendChild(bg);
  document.body.classList.add("sheet-open");            // stop the page behind from scrolling
  const sheet=bg.querySelector(".sheet"),grab=bg.querySelector(".grab");
  let closed=false;
  function close(){
    if(closed)return;closed=true;
    sheet.style.transition="transform .26s cubic-bezier(.4,0,.7,1)";
    sheet.style.transform="translateY(110%)";
    bg.style.transition="opacity .24s ease";bg.style.opacity="0";
    setTimeout(()=>{bg.remove();
      if(!document.querySelector(".sheet-bg"))document.body.classList.remove("sheet-open");},250);
  }
  bg.onclick=e=>{if(e.target===bg)close();};
  /* drag the notch down to dismiss */
  let sy=0,dragging=false;
  grab.addEventListener("pointerdown",e=>{sy=e.clientY;dragging=true;sheet.style.transition="none";
    try{grab.setPointerCapture(e.pointerId);}catch(_){}});
  grab.addEventListener("pointermove",e=>{if(!dragging)return;e.preventDefault();
    const dy=Math.max(0,e.clientY-sy);sheet.style.transform=`translateY(${dy}px)`;
    bg.style.opacity=String(Math.max(.25,1-dy/420));});
  const endDrag=e=>{if(!dragging)return;dragging=false;
    const dy=Math.max(0,((e&&e.clientY)||sy)-sy);
    sheet.style.transition="transform .3s cubic-bezier(.2,.85,.3,1)";
    if(dy>90)close();else{sheet.style.transform="";bg.style.opacity="";}};
  grab.addEventListener("pointerup",endDrag);
  grab.addEventListener("pointercancel",endDrag);
  /* A restrained top-edge pull gives scroll sheets native-feeling resistance. */
  let pullY=0,pulling=false;
  sheet.addEventListener("touchstart",e=>{if(!prefersReduce()&&sheet.scrollTop<=0&&e.touches.length===1){pullY=e.touches[0].clientY;pulling=true;}},{passive:true});
  sheet.addEventListener("touchmove",e=>{if(!pulling||sheet.scrollTop>0)return;const dy=e.touches[0].clientY-pullY;if(dy<=0)return;
    if(e.cancelable)e.preventDefault();const y=Math.min(28,Math.pow(dy,.72));sheet.style.transition="none";sheet.style.transform=`translateY(${y}px)`;
    bg.style.opacity=String(Math.max(.88,1-y/240));},{passive:false});
  sheet.addEventListener("touchend",()=>{if(!pulling)return;pulling=false;sheet.style.transition="transform .32s cubic-bezier(.2,.8,.25,1)";sheet.style.transform="";bg.style.opacity="";});
  sheet.addEventListener("touchcancel",()=>{pulling=false;sheet.style.transform="";bg.style.opacity="";});
  return {bg,close};}
function accentSheet(){const s=openSheet(`<h3>Accent color</h3><div class="chips">${Object.entries(ACCENTS).map(([k,v])=>
  `<button class="chip ${state.accent===k?"on":""}" data-a="${k}" style="border-color:${v}"><span style="display:inline-block;width:12px;height:12px;border-radius:50%;background:${v};vertical-align:-1px;margin-right:6px"></span>${k}</button>`).join("")}</div>`);
  s.bg.querySelectorAll("[data-a]").forEach(b=>b.onclick=()=>{state.accent=b.dataset.a;s.close();mSaveProfile();});}
function partnerSheet(){
  if(state.partnerId){
    const s=openSheet(`<h3>Partner</h3>
      <div class="partnercard" style="margin:0 0 14px"><span class="pav">${(state.partnerName||'?').trim().charAt(0).toUpperCase()}</span>
        <div class="pmain"><b>${escapeHtml(state.partnerName||'Your partner')}</b><span>Linked 💞</span></div></div>
      <p class="note">You each see the other's daily progress on the Today screen — counts only, never each other's tasks.</p>
      <button class="btn danger" id="p-unlink" style="margin-top:12px">Unlink</button>`);
    s.bg.querySelector("#p-unlink").onclick=()=>{if(confirm("Unlink from your partner?")){unlinkPartner();s.close();}};
    return;
  }
  const s=openSheet(`<h3>Link with your partner</h3>
    <p class="note" style="margin-bottom:14px">Link your two accounts to gently see each other's daily progress. One of you taps "Show my code", the other types it in — either order.</p>
    <button class="btn ghost" id="p-gen">Show my code</button>
    <div id="p-code" style="text-align:center;font-size:34px;font-weight:700;letter-spacing:.15em;margin:14px 0;color:var(--accent);min-height:20px"></div>
    <div class="field" style="margin-top:4px"><label>Enter partner's code</label>
      <input id="p-in" inputmode="numeric" maxlength="6" placeholder="6-digit code"></div>
    <button class="btn" id="p-link">Link</button>`);
  s.bg.querySelector("#p-gen").onclick=async()=>{
    const code=String(Math.floor(100000+Math.random()*900000));
    s.bg.querySelector("#p-code").textContent=code;
    await push(()=>SB.from("couple_links").upsert({user_id:userId,code,code_expires:new Date(Date.now()+15*60000).toISOString(),updated_at:new Date().toISOString()},{onConflict:"user_id"}));
    const h=s.bg.querySelector("#p-code");h.insertAdjacentHTML("afterend",`<p class="note" style="text-align:center">Have your partner enter this within 15 minutes.</p>`);
  };
  s.bg.querySelector("#p-link").onclick=async()=>{
    const code=(s.bg.querySelector("#p-in").value||"").trim();
    if(code.length!==6){s.bg.querySelector("#p-in").focus();return;}
    const {data,error}=await SB.rpc("link_partner",{p_code:code});
    if(error||!data||!data.ok){alert((data&&data.error)||"Couldn't link — check the code and try again.");return;}
    s.close();await enterApp();
  };
}
/* Admin hub: approve / deny who can use the app. */
function membersSheet(){
  const s=openSheet(`<h3>Members</h3><p class="note" style="margin-bottom:10px">Approve or deny people who requested access.</p><div id="mem-list"><div class="empty">Loading…</div></div>`);
  const list=s.bg.querySelector("#mem-list");
  async function reload(){
    const {data,error}=await SB.from("access").select("*").order("requested_at",{ascending:true});
    if(error){list.innerHTML=`<div class="empty">Couldn't load: ${escapeHtml(error.message)}</div>`;return;}
    const rows=data||[];
    const order={pending:0,approved:1,denied:2};
    rows.sort((a,b)=>(order[a.status]-order[b.status]));
    list.innerHTML=rows.map(r=>{
      const badge=r.status==="approved"?'<span style="color:var(--good)">✓ approved</span>':r.status==="denied"?'<span style="color:#b4483f">✕ denied</span>':'<span style="color:var(--warn)">• pending</span>';
      const ctrls=r.is_admin?'<span style="color:var(--muted);font-size:13px">owner</span>':
        `<div style="display:flex;gap:6px">
          <button class="chip ${r.status==="approved"?"on":""}" data-ap="${r.user_id}">Approve</button>
          <button class="chip" data-dn="${r.user_id}">Deny</button></div>`;
      return `<div class="mrow"><div class="t">${escapeHtml(r.email||r.user_id.slice(0,8)+"…")}${r.is_admin?' 👑':''}
        <div style="font-size:12px;margin-top:2px">${badge}</div></div>${ctrls}</div>`;
    }).join("")||'<div class="empty">No requests yet.</div>';
    list.querySelectorAll("[data-ap]").forEach(b=>b.onclick=async()=>{await SB.from("access").update({status:"approved",decided_at:new Date().toISOString()}).eq("user_id",b.dataset.ap);reload();});
    list.querySelectorAll("[data-dn]").forEach(b=>b.onclick=async()=>{await SB.from("access").update({status:"denied",decided_at:new Date().toISOString()}).eq("user_id",b.dataset.dn);reload();});
  }
  reload();
}
function unlinkPartner(){
  state.partnerId=null;state.partnerName=null;state.partnerStatus=null;
  push(()=>SB.from("couple_links").upsert({user_id:userId,partner_id:null,code:null,code_expires:null,updated_at:new Date().toISOString()},{onConflict:"user_id"}));
  render();
}
function manageSheet(){
  const s=openSheet(`<h3>Manage tasks</h3><div id="mg-list"></div>
    <button class="btn ghost" id="mg-add" style="margin-top:14px">＋ Add a task</button>`);
  const list=s.bg.querySelector("#mg-list");
  function draw(){
    const active=state.tasks.filter(t=>!t.archived).sort((a,b)=>(a.sort_index||0)-(b.sort_index||0));
    const arch=state.tasks.filter(t=>t.archived);
    list.innerHTML=(active.length?active.map((t,i)=>`
      <div class="mrow"><div class="rowsym">${symChar(t.sym)}</div>
        <div class="t">${escapeHtml(t.title)}<div style="font-size:12px;color:var(--muted)">${ruleLabel(t)}${t.time?" · "+fmt12(t.time):""}</div></div>
        <div class="mgacts">
          <button class="mgbtn" data-up="${t.id}" ${i===0?"disabled":""} aria-label="Move up">↑</button>
          <button class="mgbtn" data-down="${t.id}" ${i===active.length-1?"disabled":""} aria-label="Move down">↓</button>
          <button class="mgbtn ed" data-edit="${t.id}">Edit</button>
        </div></div>`).join(""):'<div class="empty">No tasks yet — add one below.</div>')
      +(arch.length?`<div class="grouphead" style="padding:16px 0 4px">Archived</div>`+arch.map(t=>`
        <div class="mrow"><div class="rowsym" style="opacity:.5">${symChar(t.sym)}</div>
          <div class="t" style="color:var(--muted)">${escapeHtml(t.title)}</div>
          <button class="mgbtn" data-unarch="${t.id}">Restore</button></div>`).join(""):"");
    list.querySelectorAll("[data-up]").forEach(b=>{if(!b.disabled)b.onclick=()=>{mMove(b.dataset.up,-1);draw();};});
    list.querySelectorAll("[data-down]").forEach(b=>{if(!b.disabled)b.onclick=()=>{mMove(b.dataset.down,1);draw();};});
    list.querySelectorAll("[data-edit]").forEach(b=>b.onclick=()=>{s.close();editSheet(state.tasks.find(x=>x.id===b.dataset.edit));});
    list.querySelectorAll("[data-unarch]").forEach(b=>b.onclick=()=>{mArchive(b.dataset.unarch,false);draw();});
  }
  s.bg.querySelector("#mg-add").onclick=()=>{s.close();editSheet(null);};
  draw();
}
function editSheet(task){const isNew=!task;
  const t=task?JSON.parse(JSON.stringify(task)):{id:uid(),title:"",sym:"check",group:"anytime",time:"",rule:{type:"daily"}};
  const groupOpts=GROUPS.map(g=>`<option value="${g.k}" ${t.group===g.k?"selected":""}>${g.t}</option>`).join("");
  const rt=t.rule.type,days=t.rule.days||[];
  const adv = !!(t.appUrl||t.measureUnit||t.hydration||t.keystone); // auto-expand if any are set
  const s=openSheet(`<h3>${isNew?"New task":"Edit task"}</h3>
    <div class="field"><label>Title</label><input id="f-title" value="${escapeAttr(t.title)}" placeholder="e.g. Stretch"></div>
    <div class="field"><label>Icon</label><div class="chips" id="f-sym">${SYMS.map(sm=>`<button class="chip ${t.sym===sm?"on":""}" data-sym="${sm}">${symChar(sm)}</button>`).join("")}</div></div>
    <div class="field"><label>Group</label><select id="f-group">${groupOpts}</select></div>
    <div class="field"><label>Reminder time (optional)</label><input id="f-time" type="time" value="${t.time||""}">
      <label style="display:flex;align-items:center;gap:10px;margin:10px 0 0;font-size:15px"><input type="checkbox" id="f-remind" ${t.remind!==false?"checked":""} style="width:20px;height:20px"> Remind me at this time</label>
      <div class="note">Time only sets a reminder — it never changes where the task sits in your list.</div>
    </div>
    <div class="field"><label>Repeat</label><div class="seg" id="f-rt">
      <button data-rt="daily" class="${rt==="daily"?"on":""}">Daily</button>
      <button data-rt="weekdays" class="${rt==="weekdays"?"on":""}">Days</button>
      <button data-rt="weekly" class="${rt==="weekly"?"on":""}">Weekly</button></div>
      <div class="wdays" id="f-days" style="margin-top:10px;${rt==="daily"?"display:none":""}">
      ${WD_SHORT.map((d,i)=>`<button class="chip ${(rt==="weekly"?t.rule.day===i:days.includes(i))?"on":""}" data-day="${i}">${d[0]}</button>`).join("")}</div></div>
    ${adv?"":'<button class="swap" id="f-advtog" style="margin:0 0 12px">More options</button>'}
    <div id="f-adv" style="display:${adv?"block":"none"}">
      <div class="field"><label>Open app when tapped (optional)</label>
        <input id="f-app" value="${escapeAttr(t.appUrl||"")}" placeholder="mfp://  or  https://…">
        <div class="chips" style="margin-top:8px">
          <button class="chip" type="button" data-app="mfp://">MyFitnessPal</button>
          <button class="chip" type="button" data-app="youversion://">Bible</button>
          <button class="chip" type="button" data-app="instagram://">Instagram</button>
          <button class="chip" type="button" data-app="">Clear</button></div></div>
      <div class="field"><label>Track a number (optional)</label>
        <input id="f-unit" value="${escapeAttr(t.measureUnit||"")}" placeholder="unit — e.g. hours, min, reps">
        <div class="note">Tapping the task asks for a number (sleep hours, gym minutes); History shows a trend.</div></div>
      <label style="display:flex;align-items:center;gap:10px;margin:6px 0 10px;font-size:15px"><input type="checkbox" id="f-hyd" ${t.hydration?"checked":""} style="width:20px;height:20px"> Measurable water goal</label>
      <label style="display:flex;align-items:center;gap:10px;margin:0 0 10px;font-size:15px"><input type="checkbox" id="f-key" ${t.keystone?"checked":""} style="width:20px;height:20px"> Non-negotiable <span style="color:var(--muted);font-size:13px">— a core task; a day "counts" if you hit these</span></label>
    </div>
    <button class="btn" id="f-save">${isNew?"Add task":"Save"}</button>
    ${isNew?"":`<div style="display:flex;gap:8px;margin-top:10px"><button class="btn ghost" id="f-dup" style="flex:1">Duplicate</button><button class="btn ghost" id="f-arch" style="flex:1">${t.archived?"Unarchive":"Archive"}</button></div>
    <button class="btn danger" id="f-del" style="margin-top:10px">Delete task</button>`}`);
  const tog=s.bg.querySelector("#f-advtog");if(tog)tog.onclick=()=>{s.bg.querySelector("#f-adv").style.display="block";tog.style.display="none";};
  let sym=t.sym,rtype=rt,wsel=new Set(days),wday=(t.rule.day??1);
  s.bg.querySelectorAll("[data-sym]").forEach(b=>b.onclick=()=>{sym=b.dataset.sym;s.bg.querySelectorAll("[data-sym]").forEach(x=>x.classList.toggle("on",x===b));});
  s.bg.querySelectorAll("[data-app]").forEach(b=>b.onclick=()=>{s.bg.querySelector("#f-app").value=b.dataset.app;});
  s.bg.querySelectorAll("[data-rt]").forEach(b=>b.onclick=()=>{rtype=b.dataset.rt;s.bg.querySelectorAll("[data-rt]").forEach(x=>x.classList.toggle("on",x===b));s.bg.querySelector("#f-days").style.display=rtype==="daily"?"none":"flex";});
  s.bg.querySelectorAll("[data-day]").forEach(b=>b.onclick=()=>{const i=+b.dataset.day;
    if(rtype==="weekly"){wday=i;s.bg.querySelectorAll("[data-day]").forEach(x=>x.classList.toggle("on",x===b));}
    else{if(wsel.has(i))wsel.delete(i);else wsel.add(i);b.classList.toggle("on");}});
  s.bg.querySelector("#f-save").onclick=()=>{const title=s.bg.querySelector("#f-title").value.trim();if(!title){s.bg.querySelector("#f-title").focus();return;}
    const nt={id:t.id,title,sym,group:s.bg.querySelector("#f-group").value,time:s.bg.querySelector("#f-time").value,hydration:s.bg.querySelector("#f-hyd").checked,keystone:s.bg.querySelector("#f-key").checked,remind:s.bg.querySelector("#f-remind").checked,measureUnit:s.bg.querySelector("#f-unit").value.trim(),appUrl:s.bg.querySelector("#f-app").value.trim(),sort_index:t.sort_index,archived:!!t.archived};
    if(rtype==="daily")nt.rule={type:"daily"};else if(rtype==="weekly")nt.rule={type:"weekly",day:wday};else nt.rule={type:"weekdays",days:[...wsel].sort()};
    if(nt.rule.type==="weekdays"&&!nt.rule.days.length)nt.rule={type:"daily"};
    s.close();mUpsertTask(nt);};
  const del=s.bg.querySelector("#f-del");if(del)del.onclick=()=>{s.close();mDeleteWithUndo(t.id);};
  const dup=s.bg.querySelector("#f-dup");if(dup)dup.onclick=()=>{s.close();mDuplicate(t);};
  const arch=s.bg.querySelector("#f-arch");if(arch)arch.onclick=()=>{s.close();mArchive(t.id,!t.archived);};}
function ruleLabel(t){const r=t.rule||{type:"daily"};if(r.type==="daily")return "Every day";
  if(r.type==="weekly")return "Every "+["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"][r.day];
  const d=r.days||[];if(d.length===5&&d.join()==="0,1,2,3,4")return "Sun–Thu";return d.map(i=>WD_SHORT[i]).join(", ");}

/* ---------- utils ---------- */
function fmt12(hm){if(!hm)return"";let[h,m]=hm.split(":").map(Number);const ap=h<12?"AM":"PM";h=h%12||12;return `${h}:${String(m).padStart(2,"0")} ${ap}`;}
function hmToMin(t){if(!t)return null;const[h,m]=t.split(":").map(Number);return h*60+m;}
function nowMinutes(){const p=denverParts();return (p.hour==="24"?0:+p.hour)*60 + +p.minute;}
function escapeHtml(s){return (s||"").replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));}
function escapeAttr(s){return escapeHtml(s).replace(/'/g,"&#39;");}

/* ---------- rollover + connectivity ---------- */
let lastDay=todayStr();
async function silentRefresh(){                 // re-pull from server without a spinner
  if(!state)return;
  try{const r=await loadAll();if(!r.needsOnboarding&&unlocked)render();setSync(true);}
  catch(e){setSync(false);}
}
setInterval(()=>{if(!state||!unlocked)return;const d=todayStr();if(d!==lastDay){lastDay=d;render();}},30000);
document.addEventListener("visibilitychange",()=>{
  if(document.hidden){hiddenAt=Date.now();return;}
  if(!state)return;
  if(unlocked&&getLockCode()&&Date.now()-hiddenAt>LOCK_GRACE){unlocked=false;showApp();return;} // re-lock only if a code is set
  lastDay=todayStr();silentRefresh();
});
window.addEventListener("online",()=>{setSync(true);flushOutbox();silentRefresh();});
window.addEventListener("offline",()=>setSync(false));

/* ---------- go ---------- */
(function applyStoredTheme(){try{const t=localStorage.getItem("cairn_theme");if(t)document.documentElement.setAttribute("data-theme",t);}catch(e){}updateThemeMeta();})();
startLaunch();
if(!CFG.SUPABASE_URL||CFG.SUPABASE_URL.includes("PASTE")){
  root.innerHTML='<div class="auth"><h1>Setup needed</h1><p>Add your Supabase URL and key to config.js.</p></div>';
}else{ boot(); }
