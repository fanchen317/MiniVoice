// Synthetic host fixture: no access to the installed app or real music library.
const {app,BrowserWindow,protocol}=require('electron');
const fs=require('node:fs'),path=require('node:path');
const output=path.resolve(__dirname,'../../.build/reports/ui/word-timing-ui');
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const check=(value,message)=>{if(!value)throw Error(message);};
let win;const errors=[];
const timeout=setTimeout(()=>{console.error('Word timing UI timed out');app.exit(1);},45000);
protocol.registerSchemesAsPrivileged([{scheme:'minivoice-art',privileges:{standard:true,secure:true,supportFetchAPI:true,corsEnabled:true}}]);
const js=source=>win.webContents.executeJavaScript(source,true);
async function until(source,message){for(let n=0;n<50;n++){if(await js(source))return;await wait(100);}throw Error(message);}
async function shot(name){fs.mkdirSync(output,{recursive:true});fs.writeFileSync(path.join(output,name+'.png'),(await win.webContents.capturePage()).toPNG());}
async function click(selector){await js(`document.querySelector(${JSON.stringify(selector)}).click()`);await wait(150);}
app.whenReady().then(async()=>{try{
 protocol.handle('minivoice-art',()=>new Response('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><path fill="#315d58" d="M0 0h512v512H0z"/></svg>',{headers:{'Content-Type':'image/svg+xml','Access-Control-Allow-Origin':'*'}}));
 win=new BrowserWindow({show:false,width:1040,height:800,webPreferences:{nodeIntegration:false,contextIsolation:true,backgroundThrottling:false}});
 win.webContents.on('console-message',(_event,level,message)=>{if(level>=3)errors.push(message);});
 await win.loadURL((process.env.MINIVOICE_WORD_TEST_URL||'http://127.0.0.1:5198')+'/tests/wall-desktop.html');
 await until("!!window.desktopWallFixture&&!!document.querySelector('.wall-surface')",'Fixture missing');
 await js(`window.wordEnabled=true;window.savedHostCommand=window.miniVoice.command;window.miniVoice.command=async(name,payload={})=>{if(name==='desktopSettings')return {...await window.savedHostCommand(name,payload),wordTimingCacheEnabled:window.wordEnabled};if(name==='desktopPreference'&&payload.key==='wordTimingCache'){window.wordEnabled=payload.value!=='disabled';window.desktopWallFixture.calls.push({name,payload});return true;}if(name==='tasks'&&payload.operation==='clearFinished'){window.desktopWallFixture.state.tasks={};window.desktopWallFixture.theme('dark');return true;}return window.savedHostCommand(name,payload);};window.desktopWallFixture.open('settings');`);
 await until("!!document.querySelector('[data-own-surface=settings] nav button')",'Settings missing');
 await js("Array.from(document.querySelectorAll('[data-own-surface=settings] nav button')).find(n=>n.textContent==='歌词匹配').click()");
 const toggle='[role=checkbox][aria-label="后台分析逐行歌词"]';
 await until(`document.querySelector(${JSON.stringify(toggle)})?.getAttribute('aria-checked')==='true'`,'Word analysis default missing');
 for(const [key,expected] of [['Space','false'],['Enter','true']]){
  await js(`document.querySelector(${JSON.stringify(toggle)}).focus()`);
  win.webContents.sendInputEvent({type:'keyDown',keyCode:key});win.webContents.sendInputEvent({type:'keyUp',keyCode:key});
  await until(`document.querySelector(${JSON.stringify(toggle)})?.getAttribute('aria-checked')==='${expected}'`,'Keyboard preference did not persist');
 }
 check(await js("window.desktopWallFixture.calls.filter(c=>c.name==='desktopPreference'&&c.payload.key==='wordTimingCache').map(c=>c.payload.value).join(',')==='disabled,enabled'"),'Preference submitted more than once');
 for(const theme of ['light','dark']){await js(`window.desktopWallFixture.theme('${theme}')`);await wait(200);await shot('settings-'+theme);}
 win.setContentSize(360,800);await wait(300);
 check(await js(`(()=>{const r=document.querySelector(${JSON.stringify(toggle)}).getBoundingClientRect();return r.x>=0&&r.right<=innerWidth})()`),'Narrow settings toggle overflow');
 await click('[aria-label="关闭设置"]');win.setContentSize(1040,800);
 await js("window.desktopWallFixture.state.tasks={wordTiming:{phase:'analyzing',title:'合成测试',pending:3,completed:2,failed:1}};window.desktopWallFixture.theme('dark')");
 await until("!!document.querySelector('[aria-label=\"后台任务：1 项进行中\"]')",'Background count missing');
 await click('[aria-label="后台任务：1 项进行中"]');
 await until("document.querySelector('.background-tasks-panel')?.textContent.includes('合成测试')",'Background word analysis missing');
 check(await js("!!document.querySelector('.task-row .spinner')&&document.querySelector('.task-row').textContent.includes('队列 3')"),'Analysis state/count missing');
 await shot('background-analyzing');
 await js("window.desktopWallFixture.state.tasks.wordTiming={phase:'needsReview',completed:2,failed:1,pending:0};window.desktopWallFixture.theme('light')");
 await until("document.querySelector('.background-tasks-panel')?.textContent.includes('结果待校正，保留逐行歌词')",'Unreliable result did not retain fallback');
 check(await js("!document.querySelector('.task-row .spinner')"),'Finished analysis left spinner');await shot('background-needs-review');
 await js("Array.from(document.querySelectorAll('.task-panel-actions button')).find(n=>n.textContent==='一键清理').click()");
 await until("!document.querySelector('.background-tasks-panel')",'Clear left stale task visible');
 check(!errors.some(message=>/Uncaught|Maximum update|TypeError|ReferenceError/.test(message)),errors.join('\n'));
 console.log('PASS word cache settings keyboard/persistence/themes/narrow layout; background analyzing/fallback/clear');
 clearTimeout(timeout);win.destroy();app.quit();
}catch(error){console.error(error);clearTimeout(timeout);app.exit(1);}});
