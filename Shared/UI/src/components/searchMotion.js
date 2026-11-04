// Grow before opening; collapse the field and shrink the lens together.
// Re-entering during collapse must not run a stale close.
export function createWallSearchMotion(onPhase,{schedule=setTimeout,cancel=clearTimeout,reduced=()=>false}={}){
  let phase='closed',timer;
  function clear(){cancel(timer);timer=undefined;}
  function set(next){phase=next;onPhase(next);}
  function later(next,delay,after){timer=schedule(()=>{timer=undefined;set(next);after?.();},delay);}
  return {
    open(){
      clear();
      if(reduced()){set('expanded');return;}
      if(phase==='expanded')return;
      if(phase==='collapsing'){set('expanded');return;}
      set('growing');later('expanded',240);
    },
    close(){
      clear();
      if(reduced()){set('closed');return;}
      if(phase==='closed')return;
      if(phase==='expanded'||phase==='collapsing'){
        set('collapsing');later('closed',360);
      }else{set('collapsing');later('closed',360);}
    },
    reset(){clear();set('closed');},
    dispose:clear,
  };
}
