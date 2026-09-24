import 'package:flutter/material.dart';

import '../../database/database_manager.dart';
import '../../search/cloud_search_engine.dart';
import '../../search/search_engine.dart';
import '../person/cloud_person_details_page.dart';
import '../person/person_details_page.dart';

class _LookupOption {
  final String code; final String name;
  const _LookupOption({required this.code, required this.name});
}
class _ValueOption { final String value; const _ValueOption(this.value); }
enum _SearchSource { local, cloud }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final nameController=TextEditingController(); final fatherController=TextEditingController();
  final grandfatherController=TextEditingController(); final familyController=TextEditingController();
  final identityController=TextEditingController(); final motherController=TextEditingController();
  final birthDateController=TextEditingController();
  final cloudEngine=CloudSearchEngine();
  _SearchSource source=_SearchSource.local;
  bool busy=false, loadingFilters=true; String? error, filterError;
  String? selectedProvinceCode, selectedAreaCode, selectedGender, selectedMaritalStatus, selectedDistrict, selectedNeighborhood, selectedBirthplace, selectedWorkplace;
  List<_LookupOption> provinces=[], areas=[]; List<_ValueOption> genders=[], maritalStatuses=[], districts=[], neighborhoods=[], birthplaces=[], workplaces=[];
  List<Map<String,Object?>> rows=[]; List<CloudPerson> cloudRows=[]; bool cloudHasMore=false; int cloudOffset=0;

  @override void initState(){super.initState(); _loadFilters();}
  @override void dispose(){nameController.dispose(); fatherController.dispose(); grandfatherController.dispose(); familyController.dispose(); identityController.dispose(); motherController.dispose(); birthDateController.dispose(); cloudEngine.close(); super.dispose();}

  Future<List<_ValueOption>> _loadValues(dynamic db,String table,String column) async {
    final result=await db.rawQuery('SELECT DISTINCT "$column" AS value FROM "$table" WHERE "$column" IS NOT NULL AND TRIM(CAST("$column" AS TEXT)) <> "" ORDER BY "$column"');
    return result.map((row)=>_ValueOption(row['value']?.toString().trim() ?? '')).where((option)=>option.value.isNotEmpty).toList();
  }

  Future<void> _loadFilters() async {
    try {
      final db=await DatabaseManager().open();
      final provinceRows=await db.rawQuery('SELECT "رقم المحافظة" AS code, "اسم المحافظة" AS name FROM "المحافظات" ORDER BY "اسم المحافظة"');
      final areaRows=await db.rawQuery('SELECT "رمز المنطقة" AS code, "اسم النطقة" AS name FROM "المناطق" ORDER BY "اسم النطقة"');
      final loadedProvinces=provinceRows.map((row)=>_LookupOption(code:row['code']?.toString()??'',name:row['name']?.toString()??'')).where((o)=>o.code.isNotEmpty).toList();
      final loadedAreas=areaRows.map((row)=>_LookupOption(code:row['code']?.toString()??'',name:row['name']?.toString()??'')).where((o)=>o.code.isNotEmpty).toList();
      final loadedGenders=await _loadValues(db,'قائمة_الموظفين','الجنس');
      final loadedMaritalStatuses=await _loadValues(db,'قائمة_الموظفين','الحالة الجتماعية');
      final loadedDistricts=await _loadValues(db,'Sgaza','الناحية'); final loadedNeighborhoods=await _loadValues(db,'Sgaza','الحي');
      final loadedBirthplaces=await _loadValues(db,'Sgaza','مكان الميلاد'); final loadedWorkplaces=await _loadValues(db,'قائمة_الموظفين','مكان العمل');
      if(!mounted)return; setState(() {provinces=loadedProvinces;areas=loadedAreas;genders=loadedGenders;maritalStatuses=loadedMaritalStatuses;districts=loadedDistricts;neighborhoods=loadedNeighborhoods;birthplaces=loadedBirthplaces;workplaces=loadedWorkplaces;loadingFilters=false;filterError=null;});
    } catch(e){if(mounted)setState(() {loadingFilters=false;filterError='تعذر تحميل الفلاتر من قاعدة البيانات: $e';});}
  }

  SearchQuery _query()=>SearchQuery(name:nameController.text,father:fatherController.text,grandfather:grandfatherController.text,family:familyController.text,identity:identityController.text,mother:motherController.text,birthDate:birthDateController.text,provinceCode:selectedProvinceCode,areaCode:selectedAreaCode,gender:selectedGender,maritalStatus:selectedMaritalStatus,district:selectedDistrict,neighborhood:selectedNeighborhood,birthplace:selectedBirthplace,workplace:selectedWorkplace);

  Future<void> search() async {
    final query=_query(); if(query.isEmpty)return;
    if(source==_SearchSource.cloud && _hasCloudUnsupportedFilters(query)){setState(()=>error='هذه الفلاتر غير مدعومة من واجهة البحث السحابي الحالية: المحافظة، الحالة الاجتماعية، الناحية، الحي، مكان الميلاد، مكان العمل.');return;}
    setState(() {busy=true;error=null;});
    try {
      if(source==_SearchSource.local){
        final db=await DatabaseManager().open(); final result=await SearchEngine(db).search(query);
        if(!mounted)return; setState(()=>rows=result);
      } else {
        final result=await cloudEngine.search(query); if(!mounted)return;
        setState(() {cloudRows=result.results;cloudOffset=result.offset+result.results.length;cloudHasMore=result.hasMore;});
      }
    } catch(e){if(mounted)setState(()=>error='تعذر البحث: $e');} finally {if(mounted)setState(()=>busy=false);}
  }

  bool _hasCloudUnsupportedFilters(SearchQuery q)=>[q.provinceCode,q.maritalStatus,q.district,q.neighborhood,q.birthplace,q.workplace].any((v)=>v?.trim().isNotEmpty==true);

  Future<void> _loadMoreCloud() async {
    if(busy||!cloudHasMore)return; final query=_query(); setState(()=>busy=true);
    try { final result=await cloudEngine.search(query,offset:cloudOffset); if(!mounted)return; setState(() {cloudRows.addAll(result.results);cloudOffset=result.offset+result.results.length;cloudHasMore=result.hasMore;}); }
    catch(e){if(mounted)setState(()=>error='تعذر تحميل المزيد: $e');} finally {if(mounted)setState(()=>busy=false);}
  }

  Widget _field(TextEditingController controller,String label,{TextInputAction action=TextInputAction.next})=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:controller,textInputAction:action,onSubmitted:(_){if(action==TextInputAction.search)search();},decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));
  Widget _dropdown(String label,String? value,List<_LookupOption> options,ValueChanged<String?> onChanged)=>Padding(padding:const EdgeInsets.only(bottom:10),child:DropdownButtonFormField<String>(initialValue:value,isExpanded:true,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),items:options.map((o)=>DropdownMenuItem<String>(value:o.code,child:Text(o.name))).toList(),onChanged:loadingFilters?null:onChanged));
  Widget _valueDropdown(String label,String? value,List<_ValueOption> options,ValueChanged<String?> onChanged)=>Padding(padding:const EdgeInsets.only(bottom:10),child:DropdownButtonFormField<String>(initialValue:value,isExpanded:true,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),items:options.map((o)=>DropdownMenuItem<String>(value:o.value,child:Text(o.value))).toList(),onChanged:loadingFilters?null:onChanged));

  void _clearFilters(){setState(() {selectedProvinceCode=null;selectedAreaCode=null;selectedGender=null;selectedMaritalStatus=null;selectedDistrict=null;selectedNeighborhood=null;selectedBirthplace=null;selectedWorkplace=null;});}

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('البحث')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SegmentedButton<_SearchSource>(
                        segments: const [
                          ButtonSegment(
                            value: _SearchSource.local,
                            label: Text('محلي'),
                            icon: Icon(Icons.storage_outlined),
                          ),
                          ButtonSegment(
                            value: _SearchSource.cloud,
                            label: Text('سحابي'),
                            icon: Icon(Icons.cloud_outlined),
                          ),
                        ],
                        selected: <_SearchSource>{source},
                        onSelectionChanged: (value) {
                          setState(() {
                            source = value.first;
                            rows = [];
                            cloudRows = [];
                            cloudHasMore = false;
                            cloudOffset = 0;
                            error = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _field(nameController, 'الاسم'),
                      _field(fatherController, 'اسم الأب'),
                      _field(grandfatherController, 'اسم الجد'),
                      _field(familyController, 'العائلة'),
                      _field(identityController, 'الهوية'),
                      _field(motherController, 'اسم الأم'),
                      _field(
                        birthDateController,
                        'تاريخ الميلاد',
                        action: TextInputAction.search,
                      ),
                      _dropdown(
                        'المحافظة',
                        selectedProvinceCode,
                        provinces,
                        (v) => setState(() => selectedProvinceCode = v),
                      ),
                      _dropdown(
                        'المنطقة',
                        selectedAreaCode,
                        areas,
                        (v) => setState(() => selectedAreaCode = v),
                      ),
                      _valueDropdown(
                        'الجنس',
                        selectedGender,
                        genders,
                        (v) => setState(() => selectedGender = v),
                      ),
                      _valueDropdown(
                        'الحالة الاجتماعية',
                        selectedMaritalStatus,
                        maritalStatuses,
                        (v) => setState(() => selectedMaritalStatus = v),
                      ),
                      _valueDropdown(
                        'الناحية',
                        selectedDistrict,
                        districts,
                        (v) => setState(() => selectedDistrict = v),
                      ),
                      _valueDropdown(
                        'الحي',
                        selectedNeighborhood,
                        neighborhoods,
                        (v) => setState(() => selectedNeighborhood = v),
                      ),
                      _valueDropdown(
                        'مكان الميلاد',
                        selectedBirthplace,
                        birthplaces,
                        (v) => setState(() => selectedBirthplace = v),
                      ),
                      _valueDropdown(
                        'مكان العمل',
                        selectedWorkplace,
                        workplaces,
                        (v) => setState(() => selectedWorkplace = v),
                      ),
                      if (filterError != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            filterError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: busy ? null : search,
                              icon: const Icon(Icons.search),
                              label: Text(
                                source == _SearchSource.local
                                    ? 'بحث محلي'
                                    : 'بحث سحابي',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: busy ? null : _clearFilters,
                            child: const Text('مسح الفلاتر'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (busy || loadingFilters)
                        const LinearProgressIndicator(),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: source == _SearchSource.local
                    ? _buildLocalResults(context)
                    : _buildCloudResults(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalResults(BuildContext context)=>rows.isEmpty?const Center(child:Text('لا توجد نتائج.')):ListView.separated(itemCount:rows.length,separatorBuilder:(_,_)=>const Divider(),itemBuilder:(context,index){final row=rows[index];return ListTile(title:Text('${row['الاسم']??''} ${row['الاب']??''} ${row['العائلة']??''}'),subtitle:Text('الهوية: ${row['الهوية']??''}\nمكان الميلاد: ${row['مكان الميلاد']??''}'),isThreeLine:true,trailing:const Icon(Icons.chevron_left),onTap:()async{final db=await DatabaseManager().open();if(!context.mounted)return;await Navigator.push(context,MaterialPageRoute(builder:(_)=>PersonDetailsPage(db:db,person:row)));},);});

  Widget _buildCloudResults(BuildContext context){
    if(cloudRows.isEmpty)return const Center(child:Text('لا توجد نتائج.'));
    return ListView.separated(itemCount:cloudRows.length+(cloudHasMore?1:0),separatorBuilder:(_,_)=>const Divider(),itemBuilder:(context,index){
      if(index==cloudRows.length)return Padding(padding:const EdgeInsets.symmetric(vertical:12),child:FilledButton(onPressed:busy?null:_loadMoreCloud,child:const Text('تحميل المزيد')));
      final person=cloudRows[index];
      return ListTile(title:Text(person.displayName.isEmpty?'بدون اسم':person.displayName),subtitle:Text('الهوية: ${person.id}\nتاريخ الميلاد: ${person.birth}'),isThreeLine:true,trailing:const Icon(Icons.chevron_left),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CloudPersonDetailsPage(person:person))));
    });
  }
}