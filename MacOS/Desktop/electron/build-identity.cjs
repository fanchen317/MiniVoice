const path=require('node:path');
function desktopIdentity(appData){return {name:'MiniVoice',userData:path.join(appData,'minivoice-desktop')};}
module.exports={desktopIdentity};
