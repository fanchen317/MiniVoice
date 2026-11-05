const {randomUUID}=require('node:crypto');
function audioControl({ipcMain,getWindow}){
 const pending=new Map();
 ipcMain.on('audio:result',(event,result)=>{const window=getWindow();if(event.sender!==window.webContents||event.senderFrame!==window.webContents.mainFrame)return;const task=pending.get(result?.id);if(!task)return;pending.delete(result.id);clearTimeout(task.timer);result.ok?task.resolve(result.value):task.reject(Error(result.error||'音频设备操作失败'));});
 return (action,payload={})=>new Promise((resolve,reject)=>{if(pending.size>=16)return reject(Error('音频设备操作繁忙'));const id=randomUUID(),timer=setTimeout(()=>{pending.delete(id);reject(Error('音频设备响应超时'));},10000);pending.set(id,{resolve,reject,timer});getWindow().webContents.send('audio:control',{id,action,payload});});
}
module.exports={audioControl};
