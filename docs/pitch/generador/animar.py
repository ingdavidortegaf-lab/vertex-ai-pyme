"""Agrega transiciones (desvanecer) a todas las diapositivas y animaciones de
entrada automáticas (aparecen solas, una tras otra) a los grupos indicados en
animar.json. Uso: python animar.py deck.pptx"""
import json, re, sys, zipfile, shutil, os

src = sys.argv[1]
tmp = src + '.tmp'
grupos = {g['slide']: g['grupos'] for g in json.load(open(os.path.join(os.path.dirname(os.path.abspath(src)), 'animar.json'), encoding='utf-8'))}

TRANS = '<p:transition spd="med"><p:fade/></p:transition>'

def timing(spids_por_grupo):
    n = [3]
    def nid():
        n[0] += 1
        return n[0]
    efectos = []
    paso = 0
    for g in spids_por_grupo:
        for spid in g:
            a, b, c = nid(), nid(), nid()
            efectos.append(
                f'<p:par><p:cTn id="{a}" presetID="10" presetClass="entr" presetSubtype="0" fill="hold" nodeType="withEffect">'
                f'<p:stCondLst><p:cond delay="{paso}"/></p:stCondLst><p:childTnLst>'
                f'<p:set><p:cBhvr><p:cTn id="{b}" dur="1" fill="hold"><p:stCondLst><p:cond delay="0"/></p:stCondLst></p:cTn>'
                f'<p:tgtEl><p:spTgt spid="{spid}"/></p:tgtEl><p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst></p:cBhvr>'
                f'<p:to><p:strVal val="visible"/></p:to></p:set>'
                f'<p:animEffect transition="in" filter="fade"><p:cBhvr><p:cTn id="{c}" dur="450"/>'
                f'<p:tgtEl><p:spTgt spid="{spid}"/></p:tgtEl></p:cBhvr></p:animEffect>'
                f'</p:childTnLst></p:cTn></p:par>')
        paso += 380
    return ('<p:timing><p:tnLst><p:par><p:cTn id="1" dur="indefinite" restart="never" nodeType="tmRoot"><p:childTnLst>'
            '<p:seq concurrent="1" nextAc="seek"><p:cTn id="2" dur="indefinite" nodeType="mainSeq"><p:childTnLst>'
            '<p:par><p:cTn id="3" fill="hold"><p:stCondLst><p:cond delay="indefinite"/><p:cond evt="onBegin" delay="0"><p:tn val="2"/></p:cond></p:stCondLst><p:childTnLst>'
            '<p:par><p:cTn id="100000" fill="hold"><p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst>'
            + ''.join(efectos) +
            '</p:childTnLst></p:cTn></p:par>'
            '</p:childTnLst></p:cTn></p:par>'
            '</p:childTnLst></p:cTn><p:prevCondLst><p:cond evt="onPrev" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst>'
            '<p:nextCondLst><p:cond evt="onNext" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst></p:seq>'
            '</p:childTnLst></p:cTn></p:par></p:tnLst></p:timing>')

with zipfile.ZipFile(src) as zin, zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        m = re.match(r'ppt/slides/slide(\d+)\.xml$', item.filename)
        if m:
            n = int(m.group(1))
            xml = data.decode('utf-8')
            extra = TRANS
            if n in grupos:
                ids = {nm: i for i, nm in re.findall(r'<p:cNvPr id="(\d+)" name="([^"]+)"', xml) for i, nm in [(i, nm)]}
                ids = {}
                for i, nm in re.findall(r'<p:cNvPr id="(\d+)" name="([^"]+)"', xml):
                    ids[nm] = i
                spids = []
                for g in grupos[n]:
                    sp = [ids[nm] for nm in g if nm in ids]
                    falt = [nm for nm in g if nm not in ids]
                    if falt:
                        print(f'diapositiva {n}: no encontré {falt}')
                    if sp:
                        spids.append(sp)
                # el id 100000 es arbitrario; renumerar para que sea único y creciente
                t = timing(spids)
                extra += t.replace('id="100000"', f'id="{4 + 3 * sum(len(g) for g in spids)}"')
            assert '<p:transition' not in xml
            if '<p:extLst>' in xml.split('</p:clrMapOvr>')[-1]:
                xml = xml.replace('</p:clrMapOvr>', '</p:clrMapOvr>' + extra, 1)
            else:
                xml = xml.replace('</p:sld>', extra + '</p:sld>')
            data = xml.encode('utf-8')
        zout.writestr(item, data)
shutil.move(tmp, src)
print('animaciones y transiciones listas')
