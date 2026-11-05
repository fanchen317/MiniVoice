function shuffleNext(state,ids,delta,random=Math.random){
 const allowed=new Set(ids);state.shuffleHistory=(state.shuffleHistory||[]).filter(id=>allowed.has(id));
 if(!state.shuffleHistory.length||state.shuffleHistory[state.shuffleCursor]!==state.current){state.shuffleHistory=[state.current].filter(id=>allowed.has(id));state.shuffleCursor=0;}
 if(delta<0){state.shuffleCursor=Math.max(0,state.shuffleCursor-1);return state.shuffleHistory[state.shuffleCursor]||state.current;}
 if(state.shuffleCursor<state.shuffleHistory.length-1)return state.shuffleHistory[++state.shuffleCursor];
 state.shuffleBag=(state.shuffleBag||[]).filter(id=>allowed.has(id)&&id!==state.current);
 if(!state.shuffleBag.length)state.shuffleBag=ids.filter(id=>id!==state.current);
 if(!state.shuffleBag.length)return state.current;
 const index=Math.min(state.shuffleBag.length-1,Math.floor(random()*state.shuffleBag.length)),next=state.shuffleBag.splice(index,1)[0];state.shuffleHistory.push(next);state.shuffleCursor=state.shuffleHistory.length-1;return next;
}
module.exports={shuffleNext};
