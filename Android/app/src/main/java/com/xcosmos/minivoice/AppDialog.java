package com.xcosmos.minivoice;

import android.app.Activity;
import android.app.Dialog;
import android.content.DialogInterface;
import android.content.res.ColorStateList;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.*;
import android.widget.*;
import java.util.*;

/** App-owned modal content; Android only supplies a window and input routing. */
final class AppDialog extends Dialog {
    private final Builder spec;
    private final Map<Integer,Button> buttons=new HashMap<>();
    private AppDialog(Builder spec){super(spec.activity);this.spec=spec;requestWindowFeature(Window.FEATURE_NO_TITLE);}
    Button getButton(int which){return buttons.get(which);}
    private int dp(float value){return DialogSurface.dp(spec.activity,value);}
    @Override public void show(){
        Activity activity=spec.activity;if(activity.isFinishing()||activity.isDestroyed())return;
        AppAppearance.Palette colors=DialogSurface.palette(activity);
        LinearLayout card=new LinearLayout(activity);card.setOrientation(LinearLayout.VERTICAL);card.setPadding(dp(20),dp(12),dp(20),dp(16));card.setBackground(DialogSurface.background(activity,colors,false));card.setClipToOutline(true);
        FrameLayout grip=new FrameLayout(activity);grip.setContentDescription("下拉关闭弹窗");View handleView=new View(activity);GradientDrawable handle=new GradientDrawable();handle.setColor(colors.secondary);handle.setCornerRadius(dp(3));handleView.setBackground(handle);grip.addView(handleView,new FrameLayout.LayoutParams(dp(32),dp(4),Gravity.CENTER));card.addView(grip,new LinearLayout.LayoutParams(-1,dp(28)));
        grip.setOnTouchListener(new View.OnTouchListener(){float start;public boolean onTouch(View view,MotionEvent event){switch(event.getActionMasked()){case MotionEvent.ACTION_DOWN:card.animate().cancel();start=event.getRawY();return true;case MotionEvent.ACTION_MOVE:card.setTranslationY(Math.max(0,event.getRawY()-start));return true;case MotionEvent.ACTION_UP:case MotionEvent.ACTION_CANCEL:if(event.getActionMasked()==MotionEvent.ACTION_UP&&card.getTranslationY()>dp(72)){dismiss();}else card.animate().translationY(0).setDuration(200).start();return true;}return true;}});
        if(spec.title!=null){TextView title=text(spec.title,21,colors.text);title.setTypeface(null,Typeface.BOLD);title.setPadding(0,0,0,dp(14));title.setAccessibilityHeading(true);card.addView(title);}
        ScrollView scroll=new ScrollView(activity){@Override protected void onMeasure(int width,int height){int limit=Math.max(dp(80),(int)(getResources().getDisplayMetrics().heightPixels*.55f));super.onMeasure(width,MeasureSpec.makeMeasureSpec(Math.min(MeasureSpec.getSize(height),limit),MeasureSpec.AT_MOST));}};scroll.setFillViewport(false);ListScrollStyle.apply(scroll);
        LinearLayout content=new LinearLayout(activity);content.setOrientation(LinearLayout.VERTICAL);scroll.addView(content);
        if(spec.message!=null){TextView message=text(spec.message,16,colors.secondary);message.setTextIsSelectable(true);message.setPadding(0,0,0,dp(12));content.addView(message);}
        if(spec.view!=null){if(spec.view.getParent() instanceof ViewGroup)((ViewGroup)spec.view.getParent()).removeView(spec.view);tint(spec.view,colors);content.addView(spec.view,new LinearLayout.LayoutParams(-1,-2));}
        if(spec.items!=null)for(int i=0;i<spec.items.length;i++){final int index=i;TextView item=text((spec.single?(i==spec.checked?"●  ":"○  "):"")+spec.items[i],16,i==spec.checked&&spec.single?colors.accent:colors.text);item.setGravity(Gravity.CENTER_VERTICAL);item.setMinHeight(dp(52));item.setPadding(dp(12),dp(12),dp(12),dp(12));item.setBackground(new android.graphics.drawable.RippleDrawable(ColorStateList.valueOf(colors.accent&0x00FFFFFF|0x22000000),null,null));item.setOnClickListener(v->{if(!spec.single)dismiss();else{spec.checked=index;for(int j=0;j<content.getChildCount();j++){View child=content.getChildAt(j);if(child.getTag() instanceof Integer){int choice=(Integer)child.getTag();child.setSelected(choice==index);((TextView)child).setText((choice==index?"●  ":"○  ")+spec.items[choice]);((TextView)child).setTextColor(choice==index?colors.accent:colors.text);}}}if(spec.itemAction!=null)spec.itemAction.onClick(this,index);});item.setTag(i);item.setSelected(spec.single&&i==spec.checked);item.setAccessibilityDelegate(new View.AccessibilityDelegate(){@Override public void onInitializeAccessibilityNodeInfo(View host,android.view.accessibility.AccessibilityNodeInfo info){super.onInitializeAccessibilityNodeInfo(host,info);info.setClassName(spec.single?"android.widget.RadioButton":"android.widget.Button");info.setCheckable(spec.single);info.setChecked(host.isSelected());}});ButtonFeedback.install(item);content.addView(item,new LinearLayout.LayoutParams(-1,-2));}
        card.addView(scroll,new LinearLayout.LayoutParams(-1,-2));
        LinearLayout actions=new LinearLayout(activity);actions.setGravity(Gravity.END);actions.setPadding(0,dp(12),0,0);card.addView(actions,new LinearLayout.LayoutParams(-1,-2));
        for(int which:new int[]{BUTTON_NEUTRAL,BUTTON_NEGATIVE,BUTTON_POSITIVE})if(spec.labels.containsKey(which)){Button button=new Button(activity);button.setText(spec.labels.get(which));button.setTextSize(14);button.setAllCaps(false);button.setMinWidth(0);button.setMinimumWidth(0);button.setTextColor(which==BUTTON_POSITIVE?colors.surface:colors.accent);GradientDrawable shape=new GradientDrawable();shape.setColor(which==BUTTON_POSITIVE?colors.accent:colors.background);shape.setCornerRadius(dp(16));shape.setStroke(dp(1),colors.line);button.setBackground(shape);button.setPadding(dp(10),dp(8),dp(10),dp(8));button.setMinHeight(dp(48));LinearLayout.LayoutParams params=new LinearLayout.LayoutParams(0,-2,1);params.setMargins(dp(3),0,dp(3),0);actions.addView(button,params);buttons.put(which,button);ButtonFeedback.install(button);button.setOnClickListener(v->{dismiss();DialogInterface.OnClickListener listener=spec.callbacks.get(which);if(listener!=null)listener.onClick(this,which);});}
        setContentView(card);setCanceledOnTouchOutside(true);Window window=getWindow();if(window!=null){window.setBackgroundDrawableResource(android.R.color.transparent);window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);WindowManager.LayoutParams params=window.getAttributes();params.gravity=Gravity.BOTTOM|Gravity.CENTER_HORIZONTAL;params.width=Math.min(dp(560),activity.getResources().getDisplayMetrics().widthPixels-dp(24));params.height=-2;params.y=dp(12);params.dimAmount=colors.dark?.6f:.32f;params.windowAnimations=R.style.AppDialogAnimation;window.setAttributes(params);window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);}
        super.show();
    }
    private TextView text(CharSequence value,int size,int color){TextView view=new TextView(spec.activity);view.setText(value);view.setTextSize(size);view.setTextColor(color);return view;}
    private void tint(View view,AppAppearance.Palette colors){if(view instanceof TextView){((TextView)view).setTextColor(colors.text);((TextView)view).setHintTextColor(colors.secondary);}if(view instanceof EditText)((EditText)view).setBackgroundTintList(ColorStateList.valueOf(colors.accent));if(view instanceof ViewGroup)for(int i=0;i<((ViewGroup)view).getChildCount();i++)tint(((ViewGroup)view).getChildAt(i),colors);}
    static final class Builder {
        final Activity activity;CharSequence title,message;View view;String[] items;boolean single;int checked=-1;DialogInterface.OnClickListener itemAction;
        final Map<Integer,CharSequence> labels=new HashMap<>();final Map<Integer,DialogInterface.OnClickListener> callbacks=new HashMap<>();
        Builder(Activity activity){this.activity=activity;}
        Builder setTitle(CharSequence value){title=value;return this;}
        Builder setMessage(CharSequence value){message=value;return this;}
        Builder setView(View value){view=value;return this;}
        Builder setItems(String[] value,DialogInterface.OnClickListener action){items=value;itemAction=action;return this;}
        Builder setSingleChoiceItems(String[] value,int selected,DialogInterface.OnClickListener action){items=value;checked=selected;single=true;itemAction=action;return this;}
        private Builder button(int which,CharSequence label,DialogInterface.OnClickListener action){labels.put(which,label);callbacks.put(which,action);return this;}
        Builder setPositiveButton(CharSequence label,DialogInterface.OnClickListener action){return button(BUTTON_POSITIVE,label,action);}
        Builder setNegativeButton(CharSequence label,DialogInterface.OnClickListener action){return button(BUTTON_NEGATIVE,label,action);}
        Builder setNeutralButton(CharSequence label,DialogInterface.OnClickListener action){return button(BUTTON_NEUTRAL,label,action);}
        AppDialog create(){return new AppDialog(this);}
        AppDialog show(){AppDialog dialog=create();dialog.show();return dialog;}
    }
}
