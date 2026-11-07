const path=require('node:path');
function overlay({appearance='system',interfaceStyle='simple'}={},systemDark=false){
 const dark=interfaceStyle==='wall'||appearance==='dark'||(appearance==='system'&&systemDark);
 return {color:'#00000000',symbolColor:dark?'#f0f5f3':'#17241f',height:32};
}
function windowOptions({integrated=false,state={},systemDark=false}={}){
 return {title:'MiniVoice',icon:path.join(__dirname,'..','assets','MiniVoice.ico'),autoHideMenuBar:true,
  ...(integrated?{titleBarStyle:'hidden',titleBarOverlay:overlay(state,systemDark),backgroundColor:'#111615'}:{})};
}
module.exports={windowOptions,overlay};
