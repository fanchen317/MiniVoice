// Codes are physical macOS key codes persisted by the shared recorder.
// A null accelerator keeps a display label for keys Electron cannot distinguish.
const keys={
 0:['A'],1:['S'],2:['D'],3:['F'],4:['H'],5:['G'],6:['Z'],7:['X'],8:['C'],9:['V'],11:['B'],12:['Q'],13:['W'],14:['E'],15:['R'],16:['Y'],17:['T'],
 18:['1'],19:['2'],20:['3'],21:['4'],22:['6'],23:['5'],24:['='],25:['9'],26:['7'],27:['-'],28:['8'],29:['0'],30:[']'],31:['O'],32:['U'],33:['['],34:['I'],35:['P'],36:['Enter'],37:['L'],38:['J'],39:[null,"'"],40:['K'],41:[';'],42:['\\'],43:[','],44:['/'],45:['N'],46:['M'],47:['.'],48:['Tab'],49:['Space'],50:['`'],51:['Backspace'],53:['Escape'],
 65:['numdec','小键盘 .'],67:['nummult','小键盘 *'],69:['numadd','小键盘 +'],71:['Numlock'],75:['numdiv','小键盘 /'],76:[null,'小键盘 Enter'],78:['numsub','小键盘 -'],81:[null,'小键盘 ='],82:['num0','小键盘 0'],83:['num1','小键盘 1'],84:['num2','小键盘 2'],85:['num3','小键盘 3'],86:['num4','小键盘 4'],87:['num5','小键盘 5'],88:['num6','小键盘 6'],89:['num7','小键盘 7'],91:['num8','小键盘 8'],92:['num9','小键盘 9'],
 96:['F5'],97:['F6'],98:['F7'],99:['F3'],100:['F8'],101:['F9'],103:['F11'],105:['F13'],106:['F16'],107:['F14'],109:['F10'],111:['F12'],113:['F15'],114:['Insert'],115:['Home'],116:['PageUp'],117:['Delete'],118:['F4'],119:['End'],120:['F2'],121:['PageDown'],122:['F1'],123:['Left','←'],124:['Right','→'],125:['Down','↓'],126:['Up','↑']
};
function shortcutLabel({keyCode,modifiers=0}={}){
 const entry=Number.isInteger(keyCode)?keys[keyCode]:null;if(!entry||!Number.isInteger(modifiers))return '';
 return [...(modifiers&(1<<18)?['Ctrl']:[]),...(modifiers&(1<<19)?['Alt']:[]),...(modifiers&(1<<20)?['Windows']:[]),...(modifiers&(1<<17)?['Shift']:[]),entry[1]||entry[0]].join(' + ');
}
function accelerator({keyCode,modifiers}){if(!Number.isInteger(modifiers)||!(modifiers&((1<<18)|(1<<19)|(1<<20))))throw Error('窗口快捷键需包含 Ctrl、Alt 或 Windows 键');const key=Number.isInteger(keyCode)?keys[keyCode]?.[0]:null;if(!key)throw Error('此按键暂不支持窗口全局快捷键');return [...(modifiers&(1<<18)?['Control']:[]),...(modifiers&(1<<19)?['Alt']:[]),...(modifiers&(1<<20)?['Super']:[]),...(modifiers&(1<<17)?['Shift']:[]),key].join('+');}
function windowShortcut({globalShortcut,toggle}){let current;return {register:value=>{const next=accelerator(value);if(next===current)return next;if(!globalShortcut.register(next,toggle))throw Error('快捷键已被其他程序占用');if(current)globalShortcut.unregister(current);current=next;return next;},dispose:()=>{if(current)globalShortcut.unregister(current);}};}
module.exports={accelerator,shortcutLabel,windowShortcut};
