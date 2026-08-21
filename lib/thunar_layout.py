#!/usr/bin/env python3
from pathlib import Path
import xml.etree.ElementTree as ET

path=Path.home()/".config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml"
path.parent.mkdir(parents=True,exist_ok=True)

if path.exists():
    try:
        tree=ET.parse(path)
        root=tree.getroot()
    except ET.ParseError:
        root=ET.Element("channel",{"name":"thunar","version":"1.0"})
        tree=ET.ElementTree(root)
else:
    root=ET.Element("channel",{"name":"thunar","version":"1.0"})
    tree=ET.ElementTree(root)

def prop(name, typ, value):
    el=next((x for x in root.findall("property") if x.get("name")==name),None)
    if el is None:
        el=ET.SubElement(root,"property",{"name":name})
    el.set("type",typ)
    el.set("value",value)
    for child in list(el):
        el.remove(child)

prop("default-view","string","ThunarDetailsView")
prop("last-view","string","ThunarDetailsView")
prop("last-location-bar","string","ThunarLocationEntry")
prop("last-side-pane","string","THUNAR_SIDEPANE_TYPE_HIDDEN_SHORTCUTS")
prop("last-details-view-zoom-level","string","THUNAR_ZOOM_LEVEL_38_PERCENT")
prop("last-details-view-fixed-columns","bool","false")
prop("last-details-view-visible-columns","string",
     "THUNAR_COLUMN_NAME,THUNAR_COLUMN_SIZE,THUNAR_COLUMN_TYPE,THUNAR_COLUMN_DATE_MODIFIED")
prop("last-menubar-visible","bool","true")
prop("last-statusbar-visible","bool","true")
prop("last-show-hidden","bool","false")
prop("misc-directory-specific-settings","bool","false")
prop("misc-folders-first","bool","true")
prop("misc-file-size-binary","bool","true")
prop("misc-always-show-tabs","bool","false")
prop("misc-tree-lines-in-tree-sidepane","bool","false")
prop("misc-date-style","string","THUNAR_DATE_STYLE_ISO")
prop("misc-window-title-style","string","THUNAR_WINDOW_TITLE_STYLE_FULL_PATH_WITHOUT_THUNAR_SUFFIX")

ET.indent(tree,space="  ")
tree.write(path,encoding="UTF-8",xml_declaration=True)
