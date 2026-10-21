package com.xcosmos.minivoice;

/** A drawer snapshot belongs to one player style and palette. Restore only after its transition ends. */
final class DrawerMaterialState {
    private String key="";
    private boolean pending;
    private static String key(String style,boolean dark){return style+":"+("wall".equals(style)||dark);}
    boolean prepare(String style,boolean dark,boolean open){
        boolean changed=open&&!key.equals(key(style,dark));if(changed)pending=true;return changed;
    }
    void applied(String style,boolean dark){key=key(style,dark);}
    boolean pending(){return pending;}
    boolean restore(boolean transitionRunning){if(!pending||transitionRunning)return false;pending=false;return true;}
}
