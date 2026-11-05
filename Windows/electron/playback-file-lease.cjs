async function withPlaybackFileReleased({state,id,audioControl},write){
 if(state.importing)throw Error('请等待音乐库扫描结束后保存');
 if(state.fileWriteID)throw Error('歌曲正在保存，请稍候');
 if(state.current!==id)return write();
 if(!audioControl)throw Error('无法释放当前播放文件');
 state.fileWriteID=id;let snapshot,released=false;
 try{snapshot=await audioControl('release',{id});released=true;return await write();}
 finally{try{if(released&&state.current===id){state.position=snapshot.position;await audioControl('resume',{id,position:snapshot.position,playing:snapshot.playing});}}finally{delete state.fileWriteID;}}
}
module.exports={withPlaybackFileReleased};
