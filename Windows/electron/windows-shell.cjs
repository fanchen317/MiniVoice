function closeBehavior(state){const value=state.closeBehavior||state.preferences?.closeBehavior;return ['background','pause','quit'].includes(value)?value:'background';}
function trayStyle(state){const value=state.preferences?.statusIconStyle;return ['hidden','colored','monochrome'].includes(value)?value:'hidden';}
// Without a tray icon a hidden window would be hard to recover. Keep the
// running app on the taskbar when the user has explicitly hidden the icon.
function backgroundWindowAction(state){return trayStyle(state)==='hidden'?'minimize':'hide';}
function monochromeBitmap(data){const result=Buffer.from(data);for(let i=0;i+3<result.length;i+=4){const gray=Math.round(result[i]*.114+result[i+1]*.587+result[i+2]*.299);result[i]=result[i+1]=result[i+2]=gray;}return result;}
function settingsTask({execPath,appPath,isPackaged}){return {program:execPath,arguments:(isPackaged?'':`"${appPath}" `)+'--open-settings',iconPath:execPath,iconIndex:0,title:'打开设置',description:'打开 MiniVoice 设置'};}
function removeMenu(win,openSettings){
 win.setMenu(null);win.setMenuBarVisibility(false);
 win.webContents.on('before-input-event',(event,input)=>{if(input.type==='keyDown'&&(input.control||input.meta)&&!input.alt&&input.key===','){event.preventDefault();openSettings();}});
}
module.exports={closeBehavior,trayStyle,backgroundWindowAction,monochromeBitmap,settingsTask,removeMenu};
