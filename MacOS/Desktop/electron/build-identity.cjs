const path=require('node:path');
function desktopIdentity(channel,appData){
 const debug=channel==='debug';
 return {debug,name:debug?'MiniVoice-debug':'MiniVoice',userData:path.join(appData,debug?'minivoice-desktop-debug':'minivoice-desktop')};
}
module.exports={desktopIdentity};
