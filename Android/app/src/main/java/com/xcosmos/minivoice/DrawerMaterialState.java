package com.xcosmos.minivoice;

/** Material/source identity is independent of the drawer's open/closed state. */
final class DrawerMaterialState {
    private String key="";
    static boolean liquid(String style){return "wall".equals(style);}
    boolean update(String style,boolean dark){String next=style+":"+(liquid(style)||dark);boolean changed=!key.equals(next);key=next;return changed;}
}
