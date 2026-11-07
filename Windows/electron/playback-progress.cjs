function restoreProgress(state,progress){
 if(!progress||progress.id!==state.current||!Number.isFinite(progress.position)||progress.position<0||!Number.isFinite(progress.updatedAt)||progress.updatedAt<=(state.__savedAt||0))return state;
 const song=state.songs.find(song=>song.id===state.current);if(!song)return state;
 state.position=song.duration>0&&progress.position>song.duration?0:progress.position;return state;
}
module.exports={restoreProgress};
