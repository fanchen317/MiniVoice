const windows=globalThis.miniVoice?.platform==='windows';
export const platformLabels=Object.freeze({reveal:windows?'在资源管理器中显示':'在 Finder 中显示',modifier:windows?'Ctrl、Alt 或 Windows':'Command、Option 或 Control',statusIcon:windows?'托盘图标':'菜单栏图标'});
