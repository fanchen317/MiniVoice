/** Serializes read/modify/write so fast gestures cannot overwrite each other. */
export function createWorkspaceController(adapter){
  let state={version:1,pages:{}},queue=Promise.resolve();
  return {hydrate(value){state=value&&typeof value==='object'?value:{version:1,pages:{}};},
    reduce(action){const work=queue.catch(()=>{}).then(async()=>{const next=await adapter.core({op:'state.reduce',state,action});await adapter.write(next);state=next;return next;});queue=work;return work;},
    current(){return state;},
    flush(){return queue;}};
}
export function stableSongs(previous=[],next=[]){
  if(previous===next)return previous;
  if(previous.length!==next.length)return next;
  for(let i=0;i<next.length;i++)if(JSON.stringify(previous[i])!==JSON.stringify(next[i]))return next;
  return previous;
}

export function playlistPageActions(state,oldId,newId){
 if(oldId===newId)return [];
 const before='歌单:'+oldId,after=newId==null?null:'歌单:'+newId,actions=[];
 for(const [key,page] of Object.entries(state.pages||{}))if(key.startsWith(before+'\n')){if(after)actions.push({type:'page',key:after+key.slice(before.length),patch:page});actions.push({type:'page',key,patch:null});}
 if(state.section===before)actions.push({type:'navigate',section:after||'音乐库',group:state.group||''});
 return actions;
}
