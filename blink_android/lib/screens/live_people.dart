import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/ui.dart';
import 'package:image_picker/image_picker.dart';
import '../core/live_api.dart';
import '../core/blink_home_api.dart';
import '../core/blink_auth_api.dart';
import 'blink_moment_story_gallery.dart';
import '../core/theme.dart';

class LiveDiscoverPeopleScreen extends StatefulWidget{
  const LiveDiscoverPeopleScreen({super.key});
  @override State<LiveDiscoverPeopleScreen> createState()=>_DiscoverState();
}
class _DiscoverState extends State<LiveDiscoverPeopleScreen>{
  List<dynamic> users=[];String query='';String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final rows=arr(await LiveApi.call('GET','/friends/search?q=${Uri.encodeQueryComponent(query)}'));
      if(mounted)setState((){users=rows;loading=false;error=null;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _request(String id)async{
    try{await LiveApi.call('POST','/friends/requests',{'receiverId':id});if(mounted)liveNotice(context,'Friend request sent');}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const BlinkBrandedTitle('Discover People'),actions:[
    IconButton(icon:const Icon(Icons.people),tooltip:'My friends',onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const LiveFriendsScreen()))),
    IconButton(icon:const Icon(Icons.person_add_alt),tooltip:'Requests',onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const LiveRequestsScreen()))),
  ]),body:Column(children:[
    Padding(padding:const EdgeInsets.all(14),child:TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search Blink members'),onChanged:(v)=>query=v,onSubmitted:(_)=>_load())),
    Expanded(child:loading?const Center(child:CircularProgressIndicator()):
      error!=null?liveError(error,_load):
      RefreshIndicator(onRefresh:_load,child:ListView.builder(itemCount:users.length,itemBuilder:(_,i){
        final user=users[i];return Padding(
          padding:const EdgeInsets.symmetric(horizontal:12),
          child:BlinkProListCard(
            leading:liveAvatar(user),icon:Icons.person_search_rounded,
            eyebrow:'DISCOVER BLINK MEMBERS',
            title:field(user,'name'),
            subtitle:field(user,'bio','Blink member'),
            badges:const [BlinkInfoPill('Community member',icon:Icons.people_alt_outlined)],
            onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
              builder:(_)=>LivePublicProfileScreen(userId:field(user,'id')))),
            trailing:IconButton(tooltip:'Send friend request',
              icon:const Icon(Icons.person_add_alt,color:BlinkColors.orange),
              onPressed:()=>_request(field(user,'id'))),
          ),
        );
      }))),
  ]));
}

class LiveFriendsScreen extends StatefulWidget{
  const LiveFriendsScreen({super.key});
  @override State<LiveFriendsScreen> createState()=>_FriendsState();
}
class _FriendsState extends State<LiveFriendsScreen>{
  List<dynamic> friends=[];String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final rows=arr(await LiveApi.call('GET','/friends'));if(mounted)setState((){friends=rows;loading=false;error=null;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const BlinkBrandedTitle('My Friends')),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
    RefreshIndicator(onRefresh:_load,child:ListView(children:[
      if(friends.isEmpty)const ListTile(title:Text('No friends yet'),subtitle:Text('Discover people and send a friend request.')),
      ...friends.map((row){final user=obj(obj(row)['user']);return Padding(
        padding:const EdgeInsets.symmetric(horizontal:12),
        child:BlinkProListCard(
          leading:liveAvatar(user),icon:Icons.favorite_rounded,
          eyebrow:'CONNECTED ON BLINK',
          title:field(user,'name'),
          subtitle:field(user,'bio','Your Blink friend'),
          badges:const [BlinkInfoPill('Friends',icon:Icons.verified_rounded,highlight:true)],
          onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
            builder:(_)=>LivePublicProfileScreen(userId:field(user,'id')))),
          trailing:IconButton(tooltip:'Unfriend',
            icon:const Icon(Icons.person_remove_outlined),
            onPressed:()async{
              try{await LiveApi.call('DELETE','/friends/${Uri.encodeComponent(field(user,'id'))}');await _load();}
              catch(e){if(context.mounted)liveNotice(context,e.toString());}
            }),
        ),
      );}),
    ])));
}

class LiveRequestsScreen extends StatefulWidget{
  const LiveRequestsScreen({super.key});
  @override State<LiveRequestsScreen> createState()=>_RequestsState();
}
class _RequestsState extends State<LiveRequestsScreen>{
  List<dynamic> incoming=[],outgoing=[];String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final rows=await Future.wait([
      LiveApi.call('GET','/friends/requests/incoming'),
      LiveApi.call('GET','/friends/requests/outgoing'),
    ]);if(mounted)setState((){incoming=arr(rows[0]);outgoing=arr(rows[1]);error=null;loading=false;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _respond(dynamic request,String answer)async{
    try{await LiveApi.call('POST','/friends/requests/${Uri.encodeComponent(field(request,'id'))}/$answer');await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const BlinkBrandedTitle('Friend Requests')),body:
    loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
    RefreshIndicator(onRefresh:_load,child:ListView(children:[
      const ListTile(title:Text('Incoming requests',style:TextStyle(fontWeight:FontWeight.bold))),
      if(incoming.isEmpty)const ListTile(title:Text('No incoming requests')),
      ...incoming.map((r)=>Padding(
        padding:const EdgeInsets.symmetric(horizontal:12),
        child:BlinkProListCard(
          title:field(obj(r)['sender'],'name','Blink member'),
          leading:liveAvatar(obj(r)['sender']),icon:Icons.person_add_alt_1,
          eyebrow:'FRIEND REQUEST',
          subtitle:'Would like to connect with you',
          footer:Wrap(spacing:8,runSpacing:4,children:[
            FilledButton.icon(onPressed:()=>_respond(r,'accept'),
              icon:const Icon(Icons.check_rounded,size:17),
              label:const Text('Accept')),
            OutlinedButton(onPressed:()=>_respond(r,'decline'),
              child:const Text('Decline')),
          ]),
        ),
      )),
      const Divider(),const ListTile(title:Text('Sent requests',style:TextStyle(fontWeight:FontWeight.bold))),
      ...outgoing.map((r)=>Padding(
        padding:const EdgeInsets.symmetric(horizontal:12),
        child:BlinkProListCard(
          title:field(obj(r)['receiver'],'name','Blink member'),
          leading:liveAvatar(obj(r)['receiver']),icon:Icons.schedule_rounded,
          eyebrow:'OUTGOING REQUEST',
          badges:const [BlinkInfoPill('Pending',icon:Icons.schedule_outlined)],
        ),
      )),
    ])));
}


class LiveProfileScreen extends StatefulWidget {
  const LiveProfileScreen({super.key});

  @override
  State<LiveProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends State<LiveProfileScreen> {
  Map<String, dynamic>? _profile;
  List<BlinkMoment> _moments = <BlinkMoment>[];
  List<BlinkReel> _reels = <BlinkReel>[];
  String? _error;
  String? _reelsError;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_generation;
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final profile = obj(await LiveApi.call('GET', '/profile/me'));
      final moments = await BlinkHomeApi.moments(mine: true, skip: 0, take: 40);
      if (!mounted || request != _generation) return;
      setState(() {
        _profile = profile;
        _moments = moments.where((m) => m.senderId == field(profile, 'id')).toList();
        _hasMore = moments.length == 40;
        _loading = false;
      });
      try {
        final reels = await BlinkHomeApi.myReels();
        if (!mounted || request != _generation) return;
        setState(() {
          _reels = reels.where((r) => r.authorId == field(profile, 'id')).toList();
          _reelsError = null;
        });
      } catch (error) {
        if (mounted && request == _generation) {
          setState(() => _reelsError = error.toString());
        }
      }
    } catch (error) {
      if (mounted && request == _generation) {
        setState(() { _loading = false; _error = error.toString(); });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _profile == null) return;
    final request = _generation;
    final offset = _moments.length;
    setState(() => _loadingMore = true);
    try {
      final more = await BlinkHomeApi.moments(mine: true, skip: offset, take: 40);
      if (!mounted || request != _generation) return;
      final existing = _moments.map((m) => m.id).toSet();
      setState(() {
        _moments.addAll(more.where((m) =>
          m.senderId == field(_profile, 'id') && !existing.contains(m.id)));
        _hasMore = more.length == 40;
        _loadingMore = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loadingMore = false);
        liveNotice(context, 'Unable to load older Moments: $error');
      }
    }
  }

  Future<void> _openMoment(BlinkMoment item) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlinkMomentViewer(
        moments: List<BlinkMoment>.of(_moments),
        initialIndex: _moments.indexWhere((m) => m.id == item.id),
        viewerId: field(_profile, 'id'),
      ),
    ));
    if (mounted) _load();
  }

  Future<void> _deleteMoment(BlinkMoment moment) async {
    if (_profile == null || moment.senderId != field(_profile, 'id')) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your Moment?'),
        content: const Text('This permanently removes the Moment and its media.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await BlinkHomeApi.deleteMoment(moment.id);
      if (!mounted) return;
      setState(() => _moments.removeWhere((item) => item.id == moment.id));
      liveNotice(context, 'Moment deleted from your profile.');
    } catch (error) {
      if (mounted) liveNotice(context, 'Unable to delete Moment: $error');
    }
  }

  Future<void> _openReel(BlinkReel reel) async {
    await Navigator.pushNamed(context, '/reel/view', arguments: reel.id);
    if (mounted) _load();
  }

  /// Deletion is deliberately available only in the signed-in user's
  /// profile, not while browsing or watching Reels.
  Future<void> _deleteReel(BlinkReel reel) async {
    if (_profile == null || reel.authorId != field(_profile, 'id')) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your Reel?'),
        content: const Text(
          'This permanently removes the Reel, its video and its reactions. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await BlinkHomeApi.deleteReel(reel.id);
      if (!mounted) return;
      setState(() => _reels.removeWhere((item) => item.id == reel.id));
      liveNotice(context, 'Reel deleted from your profile.');
    } catch (error) {
      if (mounted) liveNotice(context, 'Unable to delete Reel: $error');
    }
  }

  Widget _stat(String value, String label) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900,
      color: BlinkColors.orangeDark)),
    Text(label, style: const TextStyle(color: BlinkColors.muted, fontSize: 12)),
  ]);

  Widget _info(String label, String value) => value.isEmpty
    ? const SizedBox.shrink()
    : ListTile(dense: true, title: Text(label), subtitle: Text(value));

  @override
  Widget build(BuildContext context) {
    final p = _profile ?? <String, dynamic>{};
    return Scaffold(
      backgroundColor: BlinkColors.canvas,
      appBar: AppBar(title: const BlinkBrandedTitle('My Profile'), actions: [
        IconButton(
          tooltip: 'Edit profile',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => Navigator.push(context,
            MaterialPageRoute<void>(builder: (_) => const LiveEditProfileScreen()))
            .then((_) { if (mounted) _load(); }),
        ),
        IconButton(tooltip: 'Settings', icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.pushNamed(context, '/settings')),
      ]),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: BlinkColors.orange))
        : _error != null
          ? liveError(_error, _load)
          : RefreshIndicator(
              color: BlinkColors.orange,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
                children: [
                  if (field(p, 'coverKey').isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(LiveApi.url(field(p, 'coverKey')),
                        height: 140, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          height: 140, child: Icon(Icons.image_not_supported_outlined))),
                    ),
                  const SizedBox(height: 14),
                  Center(child: liveAvatar(p, radius: 48)),
                  const SizedBox(height: 10),
                  Center(child: Text(field(p, 'name'), style: Theme.of(context).textTheme.headlineSmall)),
                  if (field(p, 'bio').isNotEmpty)
                    Center(child: Text(field(p, 'bio'), textAlign: TextAlign.center)),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _stat(field(p, 'followersCount', '0'), 'Followers'),
                    _stat(field(p, 'followingCount', '0'), 'Following'),
                    _stat(field(p, 'connectionsCount', '0'), 'Friends'),
                  ]),
                  const Divider(height: 28),
                  _info('Email', field(p, 'email')),
                  _info('Occupation', field(p, 'occupation')),
                  _info('Workplace', field(p, 'workplace')),
                  _info('College', field(p, 'college')),
                  _info('High School', field(p, 'highSchool')),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/people/friends'),
                    icon: const Icon(Icons.people_outline), label: const Text('My Friends')),
                  const SizedBox(height: 20),
                  _GalleryHeading(
                    title: 'My Moments',
                    count: _moments.length,
                    onViewAll: () => Navigator.pushNamed(context, '/moments/mine')),
                  const SizedBox(height: 10),
                  if (_moments.isEmpty)
                    const Padding(padding: EdgeInsets.all(16),
                      child: Text('You have not published any Moments yet.')),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _moments.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 7, mainAxisSpacing: 7),
                    itemBuilder: (_, i) {
                      final item = _moments[i];
                      return _ProfileMediaTile(
                        url: item.mediaType == 'video' ? null : BlinkHomeApi.mediaUrl(item.mediaUrl),
                        video: item.mediaType == 'video',
                        onTap: () => _openMoment(item),
                        onDelete: () => _deleteMoment(item));
                    },
                  ),
                  if (_hasMore)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.expand_more),
                        label: Text(_loadingMore ? 'Loading...' : 'Load older Moments'),
                        onPressed: _loadingMore ? null : _loadMore)),
                  const SizedBox(height: 24),
                  _GalleryHeading(
                    title: 'My Reels',
                    count: _reels.length,
                    onViewAll: null),
                  const SizedBox(height: 10),
                  if (_reelsError != null)
                    ListTile(
                      title: const Text('Unable to load your Reels'),
                      subtitle: Text(_reelsError!),
                      trailing: TextButton(onPressed: _load, child: const Text('Retry'))),
                  if (_reels.isEmpty && _reelsError == null)
                    const Padding(padding: EdgeInsets.all(16),
                      child: Text('You have not published any Reels yet.')),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _reels.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 7, mainAxisSpacing: 7),
                    itemBuilder: (_, i) {
                      final reel = _reels[i];
                      return _ProfileMediaTile(
                        video: true,
                        url: BlinkHomeApi.mediaUrl(reel.thumbnailUrl),
                        onTap: () => _openReel(reel),
                        onDelete: () => _deleteReel(reel));
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _GalleryHeading extends StatelessWidget {
  const _GalleryHeading({required this.title, required this.count, required this.onViewAll});
  final String title;
  final int count;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(title, style: const TextStyle(
      color: BlinkColors.ink, fontSize: 19, fontWeight: FontWeight.w900))),
    Text('$count', style: const TextStyle(
      color: BlinkColors.orangeDark, fontWeight: FontWeight.bold)),
    const SizedBox(width: 6),
    if (onViewAll != null)
      TextButton(onPressed: onViewAll, child: const Text('View all')),
  ]);
}

class _ProfileMediaTile extends StatelessWidget {
  const _ProfileMediaTile({
    this.url,
    required this.video,
    required this.onTap,
    this.onDelete,
  });
  final String? url;
  final bool video;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Material(
    clipBehavior: Clip.antiAlias,
    color: BlinkColors.orangeSoft,
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      onTap: onTap,
      child: Stack(fit: StackFit.expand, children: [
        if (url != null && url!.isNotEmpty)
          Image.network(url!, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined, color: BlinkColors.orange)))
        else
          const Center(child: Icon(Icons.photo_library_outlined,
            color: BlinkColors.orange, size: 29)),
        if (video)
          const Center(child: Icon(Icons.play_circle_fill_rounded,
            color: BlinkColors.orange, size: 40)),
        if (onDelete != null)
          Positioned(
            right: 5, top: 5,
            child: Material(
              color: const Color(0xC9000000),
              borderRadius: BorderRadius.circular(8),
              child: IconButton(
                tooltip: 'Delete Reel from my profile',
                icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white, size: 19),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(
                  minHeight: 36, minWidth: 36),
              ),
            ),
          ),
      ]),
    ),
  );
}

class LiveEditProfileScreen extends StatefulWidget{
  const LiveEditProfileScreen({super.key});
  @override State<LiveEditProfileScreen> createState()=>_EditState();
}
class _EditState extends State<LiveEditProfileScreen>{
  final controllers=<String,TextEditingController>{for(final key in ['name','bio','college','highSchool','occupation','workplace']) key:TextEditingController()};
  bool busy=false;String? error;
  @override void initState(){super.initState();_load();}
  @override void dispose(){for(final c in controllers.values){c.dispose();}super.dispose();}
  Future<void> _load()async{
    try{final p=obj(await LiveApi.call('GET','/profile/me'));
      for(final item in controllers.entries){item.value.text=field(p,item.key);}
      if(mounted)setState(()=>error=null);
    }catch(e){if(mounted)setState(()=>error=e.toString());}
  }
  Future<void> _save()async{
    setState(()=>busy=true);
    try{await LiveApi.call('PATCH','/profile/me',controllers.map((k,v)=>MapEntry(k,v.text.trim())));
      if(mounted){liveNotice(context,'Profile updated');Navigator.pop(context);}
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _upload(String kind)async{
    final photo=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:85);
    if(photo==null)return;
    setState(()=>busy=true);
    try{await LiveApi.upload('/profile/me/$kind',File(photo.path));if(mounted)liveNotice(context,'Photo updated');}
    catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context) {
    const labels = <String, String>{
      'name': 'Display name',
      'bio': 'About me',
      'college': 'College',
      'highSchool': 'High school',
      'occupation': 'Occupation',
      'workplace': 'Workplace',
    };
    return BlinkCreateLayout(
      title: 'Edit Profile',
      subtitle: 'Introduce yourself to your Blink community.',
      icon: Icons.person_outline_rounded,
      busy: busy,
      primaryLabel: busy ? 'Saving profile...' : 'Save profile',
      onSubmit: _save,
      content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BlinkFormSection(
          heading: 'Your photos',
          helper: 'Choose a profile photo and a cover image.',
          children: [
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: busy ? null : () => _upload('avatar'),
              icon: const Icon(Icons.person_rounded),
              label: const Text('Change profile photo'),
            )),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: busy ? null : () => _upload('cover'),
              icon: const Icon(Icons.image_rounded),
              label: const Text('Change cover photo'),
            )),
          ],
        ),
        const SizedBox(height: 16),
        BlinkFormSection(
          heading: 'Personal details',
          helper: 'Keep your information up to date.',
          children: [
            ...controllers.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: TextField(
                controller: e.value,
                maxLines: e.key == 'bio' ? 4 : 1,
                maxLength: e.key == 'bio' ? 500 : null,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: e.key == 'bio'
                  ? TextInputAction.newline : TextInputAction.next,
                decoration: InputDecoration(
                  labelText: labels[e.key] ?? e.key,
                  alignLabelWithHint: e.key == 'bio'),
              ),
            )),
          ],
        ),
        if (error != null) Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(error!, style: const TextStyle(color: Colors.red)),
        ),
      ]),
    );
  }
}


class LivePublicProfileScreen extends StatefulWidget {
  final String userId;
  const LivePublicProfileScreen({super.key, required this.userId});

  @override
  State<LivePublicProfileScreen> createState() => _PublicState();
}

class _PublicState extends State<LivePublicProfileScreen> {
  Map<String, dynamic>? _profile;
  List<BlinkMoment> _moments = <BlinkMoment>[];
  List<BlinkReel> _reels = <BlinkReel>[];
  String _viewerId = '';
  String? _error;
  bool _loading = true;
  bool _busy = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() { _generation++; super.dispose(); }

  Future<void> _load() async {
    final request = ++_generation;
    setState(() { _loading = true; _error = null; });
    try {
      final profile = obj(await LiveApi.call('GET', '/profile/${Uri.encodeComponent(widget.userId)}'));
      final viewer = await BlinkAuthApi.cachedUser();
      final currentId = field(viewer, 'id');
      final moments = arr(profile['moments']).map((raw) {
        final data = obj(raw);
        return BlinkMoment.fromJson({
          ...data,
          'senderId': widget.userId,
          'sender': {'name': field(profile, 'name'), 'avatarKey': profile['avatarKey']},
        });
      }).toList();
      List<BlinkReel> reels = <BlinkReel>[];
      try {
        final response = arr(await LiveApi.call('GET', '/reels/user/${Uri.encodeComponent(widget.userId)}'));
        reels = response.map((item) => BlinkReel.fromJson(obj(item))).toList();
      } catch (_) {
        // The profile itself remains usable when Reels are unavailable.
      }
      if (!mounted || request != _generation) return;
      setState(() {
        _profile = profile;
        _viewerId = currentId;
        _moments = moments;
        _reels = reels;
        _loading = false;
      });
    } catch (error) {
      if (mounted && request == _generation) setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _friendAction(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (action == 'add') {
        await LiveApi.call('POST', '/friends/requests',
          {'receiverId': widget.userId});
      } else if (action == 'accept' || action == 'decline') {
        final id = field(_profile, 'incomingRequestId');
        if (id.isEmpty) throw const LiveApiError('Friend request unavailable.');
        await LiveApi.call('POST', '/friends/requests/${Uri.encodeComponent(id)}/$action');
      } else if (action == 'remove') {
        await LiveApi.call('DELETE', '/friends/${Uri.encodeComponent(widget.userId)}');
      }
      await _load();
    } catch (error) {
      if (mounted) liveNotice(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMoment(BlinkMoment moment) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlinkMomentViewer(
        moments: List<BlinkMoment>.of(_moments),
        initialIndex: _moments.indexWhere((m) => m.id == moment.id),
        viewerId: _viewerId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile ?? <String, dynamic>{};
    final relationship = field(p, 'relationship');
    return Scaffold(
      backgroundColor: BlinkColors.canvas,
      appBar: AppBar(title: BlinkBrandedTitle(field(p, 'name', 'Blink Profile'))),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: BlinkColors.orange))
        : _error != null
          ? liveError(_error, _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                children: [
                  if (field(p, 'coverKey').isNotEmpty)
                    ClipRRect(borderRadius: BorderRadius.circular(15),
                      child: Image.network(LiveApi.url(field(p, 'coverKey')),
                        height: 136, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(height: 136))),
                  const SizedBox(height: 14),
                  Center(child: liveAvatar(p, radius: 45)),
                  const SizedBox(height: 12),
                  Center(child: Text(field(p, 'name'),
                    style: Theme.of(context).textTheme.headlineSmall)),
                  if (field(p, 'bio').isNotEmpty)
                    Center(child: Text(field(p, 'bio'), textAlign: TextAlign.center)),
                  const SizedBox(height: 12),
                  Center(child: Text('${field(p,'connectionsCount','0')} connections')),
                  const SizedBox(height: 15),
                  if (relationship == 'SELF')
                    FilledButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/profile'),
                      icon: const Icon(Icons.account_circle_outlined),
                      label: const Text('My Profile')),
                  if (relationship == 'NONE')
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _friendAction('add'),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Add Friend')),
                  if (relationship == 'OUTGOING_PENDING')
                    const ListTile(
                      leading: Icon(Icons.hourglass_top, color: BlinkColors.orange),
                      title: Text('Friend request pending')),
                  if (relationship == 'INCOMING_PENDING')
                    Wrap(spacing: 8, children: [
                      FilledButton(
                        onPressed: _busy ? null : () => _friendAction('accept'),
                        child: const Text('Accept request')),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _friendAction('decline'),
                        child: const Text('Decline')),
                    ]),
                  if (relationship == 'FRIENDS')
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _friendAction('remove'),
                      icon: const Icon(Icons.people_alt_outlined),
                      label: const Text('Friends · Remove')),
                  const SizedBox(height: 20),
                  _GalleryHeading(title: 'Public Moments', count: _moments.length,
                    onViewAll: null),
                  const SizedBox(height: 10),
                  if (_moments.isEmpty)
                    const Padding(padding: EdgeInsets.all(12),
                      child: Text('No public Moments shared yet.')),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _moments.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 7, mainAxisSpacing: 7),
                    itemBuilder: (_, index) {
                      final item = _moments[index];
                      return _ProfileMediaTile(
                        video: item.mediaType == 'video',
                        url: item.mediaType == 'video'
                          ? null : BlinkHomeApi.mediaUrl(item.mediaUrl),
                        onTap: () => _openMoment(item));
                    },
                  ),
                  const SizedBox(height: 24),
                  _GalleryHeading(title: 'Reels', count: _reels.length,
                    onViewAll: null),
                  const SizedBox(height: 10),
                  if (_reels.isEmpty)
                    const Padding(padding: EdgeInsets.all(12),
                      child: Text('No Reels shared yet.')),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _reels.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 7, mainAxisSpacing: 7),
                    itemBuilder: (_, index) {
                      final reel = _reels[index];
                      return _ProfileMediaTile(
                        video: true,
                        url: BlinkHomeApi.mediaUrl(reel.thumbnailUrl),
                        onTap: () => Navigator.pushNamed(
                          context, '/reel/view', arguments: reel.id));
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
