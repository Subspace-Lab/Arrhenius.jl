"""Prepare pinned Pt inputs: SOURCE_DIR NEW_OUTPUT_DIR; never overwrite outputs."""
import pathlib,sys,shutil,hashlib,json
source,out=map(pathlib.Path,sys.argv[1:]);root=pathlib.Path(__file__).resolve().parents[2];p=root/'test/cantera_parity';out.mkdir(parents=True,exist_ok=False)
sys.path.insert(0,str(p));from reactor_reference import environment
ct,_,_,_=environment(source);ct.add_data_directory(str(source/'data'))
sys.path.insert(0,str(root/'mechanism'));from export_surface import export_surface
surf,gasfile=export_surface('ptcombust.yaml','Pt_surf',out/'pt.npz');gas=surf.adjacent['gas']
shutil.copyfile(source/'data/ptcombust.yaml',out/'ptcombust.yaml')
initial_T,initial_P,initial_X=gas.T,gas.P,gas.X.tolist();gas.equilibrate('HP')
meta={'cantera_commit':'726522be4e2a13454d8415b7ef799d621f665cf3','initial_T':initial_T,'initial_P':initial_P,'initial_X':initial_X,'equilibrium_T':gas.T,'equilibrium_X':gas.X.tolist(),'surface_T':surf.T,'surface_P':surf.P,'gas_species':gas.species_names,'surface_species':surf.species_names,'gas_reactions':gas.n_reactions,'surface_reactions':surf.n_reactions,'gri30_sha256':hashlib.sha256((source/'data/gri30.yaml').read_bytes()).hexdigest()}
text=''.join(k+' = '+json.dumps(v)+'\n' for k,v in meta.items())+'\n[sha256]\n'
for f in ['ptcombust.yaml','pt.gas.yaml','pt.source.yaml','pt.npz']:
 text+=json.dumps(f)+' = "'+hashlib.sha256((out/f).read_bytes()).hexdigest()+'"\n'
(out/'fixture.toml').write_text(text)
print('Prepared:',gas.n_species,gas.n_reactions,surf.n_species,surf.n_reactions)
