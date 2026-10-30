// Mobile labels 60–120% map to camera scales .5–1. Never clamp labels as camera units.
export const MOBILE_DEFAULT_SCALE=1/1.2;
export const clampMobileWallScale=value=>Math.max(.5,Math.min(1,Number.isFinite(value)?value:MOBILE_DEFAULT_SCALE));
export const mobileWallPercent=value=>Math.round(clampMobileWallScale(value)*120);
export const mobileWallScale=percent=>clampMobileWallScale(percent/120);
export const initialMobileWallCamera=value=>({x:Number.isFinite(value?.x)?value.x:12,y:Number.isFinite(value?.y)?value.y:80,scale:clampMobileWallScale(Number.isFinite(value?.scale)&&value.scale>0?value.scale:MOBILE_DEFAULT_SCALE)});
