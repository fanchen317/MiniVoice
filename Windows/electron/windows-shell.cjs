function settingsTask({execPath,appPath,isPackaged}){return {program:execPath,arguments:(isPackaged?'':`"${appPath}" `)+'--open-settings',iconPath:execPath,iconIndex:0,title:'打开设置',description:'打开 MiniVoice 设置'};}
function removeMenu(win,openSettings){
 win.setMenu(null);win.setMenuBarVisibility(false);
 win.webContents.on('before-input-event',(event,input)=>{if(input.type==='keyDown'&&(input.control||input.meta)&&!input.alt&&input.key===','){event.preventDefault();openSettings();}});
}
module.exports={settingsTask,removeMenu};
