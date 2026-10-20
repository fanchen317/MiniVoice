import { flushSync } from 'react-dom';

export const PLAYER_REFLOW_MS=220;
export function playerContentWidth(width,sidebar){
  return Math.max(280,width-24-(sidebar?Math.min(288,Math.max(250,width*.25))+12:0));
}
export function playerReflowFrames(from,to,fromPanel,toPanel){
  // Children move in panel coordinates. Applying screen deltas here would
  // count the panel's upward height animation twice.
  const x=(from.x-fromPanel.x)-(to.x-toPanel.x),y=(from.y-fromPanel.y)-(to.y-toPanel.y);
  return [{translate:`${x}px ${y}px`,width:`${from.width}px`,height:`${from.height}px`},
    {translate:'0px 0px',width:`${to.width}px`,height:`${to.height}px`}];
}
let current=null;
const leaves='.now-playing,.transport>.seek,.transport-buttons,.volume-row,.output-device';
function cancel(){
  if(!current)return;
  const session=current;current=null;
  for(const animation of session.animations)animation.cancel();
  Object.assign(session.panel.style,session.saved);
  if(session.layout)session.layout.style.height=session.layoutHeight;
}
export function cancelPlayerReflow(){cancel();}
export function responsivePlayerLayout(update,{start=false}={}){
  const panel=document.querySelector('.app:not(.style-wall):not(.album-mode)>.player');
  const reduced=document.documentElement.classList.contains('reduce-motion');
  const retargeting=Boolean(current)&&!start;
  const now=performance.now(),deadline=start?now+PLAYER_REFLOW_MS:current?.deadline;
  if(!panel||reduced||!deadline||deadline<=now){cancel();flushSync(update);return;}
  const before=panel.getBoundingClientRect(),workspace=document.querySelector('.app>.workspace');
  const workspaceBefore=workspace?.getBoundingClientRect();
  const cover=panel.querySelector('.mini-cover'),coverBefore=cover?.getBoundingClientRect();
  const nodes=[...panel.querySelectorAll(leaves)],frames=new Map(nodes.map(node=>[node,node.getBoundingClientRect()]));
  // Read the in-flight geometry before cancelling. Reversals and continued
  // window drags start at the visible position, with the same 220 ms deadline.
  cancel();flushSync(update);
  if(!panel.isConnected)return;
  const after=panel.getBoundingClientRect(),workspaceAfter=workspace?.getBoundingClientRect();
  const targets=new Map(nodes.filter(node=>node.isConnected).map(node=>[node,node.getBoundingClientRect()]));
  const layout=panel.querySelector('.player-layout'),layoutHeight=layout?.style.height;
  const targetLayoutHeight=layout?.getBoundingClientRect().height;
  const coverAfter=cover?.getBoundingClientRect();
  const saved=Object.fromEntries(['position','left','right','bottom','top','width','overflow'].map(key=>[key,panel.style[key]]));
  Object.assign(panel.style,{position:'absolute',left:'var(--content-left)',right:'12px',bottom:'12px',top:'auto',width:'auto',overflow:'hidden'});
  if(layout)layout.style.height=`${targetLayoutHeight}px`;
  const options={duration:Math.max(1,deadline-now),easing:retargeting?'linear':'ease-in-out'},animations=[];
  animations.push(panel.animate([{height:`${before.height}px`},{height:`${after.height}px`}],options));
  if(workspaceBefore&&workspaceAfter)animations.push(workspace.animate([{height:`${workspaceBefore.height}px`},{height:`${workspaceAfter.height}px`}],options));
  for(const node of nodes){
    const from=frames.get(node),to=targets.get(node);
    if(!from?.width||!to?.width||!from.height||!to.height)continue;
    animations.push(node.animate(playerReflowFrames(from,to,before,after),options));
  }
  if(coverBefore&&coverAfter)animations.push(cover.animate([
    {width:`${coverBefore.width}px`,height:`${coverBefore.height}px`,borderRadius:coverBefore.width>60?'13px':'7px'},
    {width:`${coverAfter.width}px`,height:`${coverAfter.height}px`,borderRadius:coverAfter.width>60?'13px':'7px'}],options));
  const session={panel,saved,layout,layoutHeight,deadline,animations};current=session;
  Promise.all(animations.map(animation=>animation.finished.catch(()=>{}))).then(()=>{
    if(current===session){current=null;Object.assign(panel.style,saved);if(layout)layout.style.height=layoutHeight;}
  });
}
