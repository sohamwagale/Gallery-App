import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:typed_data';

void main() {
  runApp(PhotoGalleryApp());
}

class PhotoGalleryApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Gallery',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark, // Setting dark theme as default
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Photo {
  final String id;
  final dynamic imageData; // File for mobile, Uint8List for web
  final DateTime dateAdded;
  final bool isWebImage;

  Photo({
    required this.id, 
    required this.imageData, 
    required this.dateAdded,
    required this.isWebImage,
  });
}

class Album {
  final String id;
  final String name;
  final List<String> photoIds;
  String? coverPhotoId;

  Album({required this.id, required this.name, required this.photoIds, this.coverPhotoId});
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Photo> _photos = [];
  final List<Album> _albums = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addSinglePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final String id = DateTime.now().millisecondsSinceEpoch.toString();
      
      if (kIsWeb) {
        // Web implementation
        final Uint8List data = await image.readAsBytes();
        setState(() {
          _photos.add(Photo(
            id: id,
            imageData: data,
            dateAdded: DateTime.now(),
            isWebImage: true,
          ));
        });
      } else {
        // Mobile implementation
        final File file = File(image.path);
        setState(() {
          _photos.add(Photo(
            id: id,
            imageData: file,
            dateAdded: DateTime.now(),
            isWebImage: false,
          ));
        });
      }
    }
  }

  Future<void> _addMultiplePhotos() async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null && images.isNotEmpty) {
      List<Photo> newPhotos = [];
      
      for (var image in images) {
        final String id = '${DateTime.now().millisecondsSinceEpoch}_${newPhotos.length}';
        
        if (kIsWeb) {
          // Web implementation
          final Uint8List data = await image.readAsBytes();
          newPhotos.add(Photo(
            id: id,
            imageData: data,
            dateAdded: DateTime.now(),
            isWebImage: true,
          ));
        } else {
          // Mobile implementation
          final File file = File(image.path);
          newPhotos.add(Photo(
            id: id,
            imageData: file,
            dateAdded: DateTime.now(),
            isWebImage: false,
          ));
        }
      }
      
      setState(() {
        _photos.addAll(newPhotos);
      });
      
      // Ask if user wants to add these to an album
      if (_albums.isNotEmpty) {
        _addMultiplePhotosToAlbum(newPhotos);
      }
    }
  }

  void _createAlbum() {
    showDialog(
      context: context,
      builder: (context) {
        String albumName = '';
        
        return AlertDialog(
          title: Text('Create New Album'),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Album Name',
            ),
            onChanged: (value) {
              albumName = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (albumName.isNotEmpty) {
                  setState(() {
                    _albums.add(Album(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: albumName,
                      photoIds: [],
                    ));
                  });
                  Navigator.pop(context);
                  
                  // If there are photos, ask if user wants to add some to the new album
                  if (_photos.isNotEmpty) {
                    _showSelectPhotosForAlbumDialog(_albums.last);
                  }
                }
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showSelectPhotosForAlbumDialog(Album album) {
    showDialog(
      context: context,
      builder: (context) {
        List<String> selectedPhotoIds = [];
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Photos to ${album.name}'),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child: _photos.isEmpty
                    ? Center(child: Text('No photos available'))
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 5,
                          mainAxisSpacing: 5,
                        ),
                        itemCount: _photos.length,
                        itemBuilder: (context, index) {
                          final photo = _photos[_photos.length - 1 - index];
                          final bool isSelected = selectedPhotoIds.contains(photo.id);
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedPhotoIds.remove(photo.id);
                                } else {
                                  selectedPhotoIds.add(photo.id);
                                }
                              });
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildPhotoWidget(photo),
                                ),
                                if (isSelected)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    this.setState(() {
                      // Add selected photos to album
                      for (var photoId in selectedPhotoIds) {
                        if (!album.photoIds.contains(photoId)) {
                          album.photoIds.add(photoId);
                        }
                      }
                      
                      // Set cover photo if not already set
                      if (album.coverPhotoId == null && selectedPhotoIds.isNotEmpty) {
                        album.coverPhotoId = selectedPhotoIds.first;
                      }
                    });
                    
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added ${selectedPhotoIds.length} photos to ${album.name}')),
                    );
                  },
                  child: Text('Add Selected'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _addMultiplePhotosToAlbum(List<Photo> photos) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add to Album?'),
          content: Text('Do you want to add these ${photos.length} photos to an album?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                
                // Show album selection dialog
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text('Select Album'),
                      content: Container(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _albums.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(_albums[index].name),
                              onTap: () {
                                setState(() {
                                  // Add all photos to selected album
                                  for (var photo in photos) {
                                    if (!_albums[index].photoIds.contains(photo.id)) {
                                      _albums[index].photoIds.add(photo.id);
                                    }
                                  }
                                  
                                  // Set cover photo if not already set
                                  if (_albums[index].coverPhotoId == null && photos.isNotEmpty) {
                                    _albums[index].coverPhotoId = photos.first.id;
                                  }
                                });
                                
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Added ${photos.length} photos to ${_albums[index].name}')),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
              child: Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  void _addPhotoToAlbum(Photo photo) {
    if (_albums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create an album first')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add to Album'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _albums.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_albums[index].name),
                  onTap: () {
                    setState(() {
                      if (!_albums[index].photoIds.contains(photo.id)) {
                        _albums[index].photoIds.add(photo.id);
                        
                        // If this is the first photo, set it as cover
                        if (_albums[index].coverPhotoId == null) {
                          _albums[index].coverPhotoId = photo.id;
                        }
                      }
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added to ${_albums[index].name}')),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _sharePhoto(Photo photo) async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sharing is not fully supported on web')),
        );
        return;
      }
      
      if (!photo.isWebImage) {
        await Share.shareFiles(
          [(photo.imageData as File).path],
          text: 'Check out this photo!',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
      );
    }
  }

  void _viewAlbum(Album album) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumViewScreen(
          album: album,
          photos: _photos,
          onSharePhoto: _sharePhoto,
        ),
      ),
    );
  }

  Widget _buildPhotoWidget(Photo photo) {
    if (photo.isWebImage) {
      // Web image (Uint8List)
      return Image.memory(
        photo.imageData,
        fit: BoxFit.cover,
      );
    } else {
      // Mobile image (File)
      return Image.file(
        photo.imageData,
        fit: BoxFit.cover,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photo Gallery'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Photos', icon: Icon(Icons.photo)),
            Tab(text: 'Albums', icon: Icon(Icons.album)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.photo_library),
            onPressed: _addMultiplePhotos,
            tooltip: 'Add Multiple Photos',
          ),
          IconButton(
            icon: Icon(Icons.create_new_folder),
            onPressed: _createAlbum,
            tooltip: 'Create Album',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Photos Tab
          _photos.isEmpty
              ? Center(child: Text('No photos yet. Tap the + icon to add some!'))
              : GridView.builder(
                  padding: EdgeInsets.all(8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    final photo = _photos[_photos.length - 1 - index];
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PhotoViewScreen(
                              photo: photo,
                              onAddToAlbum: () => _addPhotoToAlbum(photo),
                              onSharePhoto: () => _sharePhoto(photo),
                              buildPhotoWidget: _buildPhotoWidget,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildPhotoWidget(photo),
                      ),
                    );
                  },
                ),
          
          // Albums Tab
          _albums.isEmpty
              ? Center(child: Text('No albums yet. Tap the folder icon to create one!'))
              : ListView.builder(
                  itemCount: _albums.length,
                  itemBuilder: (context, index) {
                    final album = _albums[index];
                    final hasPhotos = album.photoIds.isNotEmpty;
                    
                    // Find cover photo
                    Photo? coverPhoto;
                    if (album.coverPhotoId != null) {
                      coverPhoto = _photos.firstWhere(
                        (p) => p.id == album.coverPhotoId,
                        orElse: () => hasPhotos 
                            ? _photos.firstWhere((p) => album.photoIds.contains(p.id), 
                                orElse: () => null as Photo)
                            : null as Photo,
                      );
                    } else if (hasPhotos) {
                      final firstPhotoId = album.photoIds.first;
                      coverPhoto = _photos.firstWhere(
                        (p) => p.id == firstPhotoId,
                        orElse: () => null as Photo,
                      );
                    }
                    
                    return ListTile(
                      leading: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: coverPhoto != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildPhotoWidget(coverPhoto),
                              )
                            : Icon(Icons.photo_album, size: 30),
                      ),
                      title: Text(album.name),
                      subtitle: Text('${album.photoIds.length} photos'),
                      onTap: () => _viewAlbum(album),
                      trailing: IconButton(
                        icon: Icon(Icons.add_photo_alternate),
                        onPressed: () => _showSelectPhotosForAlbumDialog(album),
                        tooltip: 'Add Photos',
                      ),
                    );
                  },
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSinglePhoto,
        child: Icon(Icons.add_a_photo),
        tooltip: 'Add Photo',
      ),
    );
  }
}

class PhotoViewScreen extends StatelessWidget {
  final Photo photo;
  final VoidCallback onAddToAlbum;
  final VoidCallback onSharePhoto;
  final Widget Function(Photo) buildPhotoWidget;

  const PhotoViewScreen({
    Key? key,
    required this.photo,
    required this.onAddToAlbum,
    required this.onSharePhoto,
    required this.buildPhotoWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photo View'),
        actions: [
          IconButton(
            icon: Icon(Icons.album),
            onPressed: onAddToAlbum,
            tooltip: 'Add to Album',
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: onSharePhoto,
            tooltip: 'Share Photo',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: buildPhotoWidget(photo),
        ),
      ),
    );
  }
}

class AlbumViewScreen extends StatelessWidget {
  final Album album;
  final List<Photo> photos;
  final Function(Photo) onSharePhoto;

  const AlbumViewScreen({
    Key? key,
    required this.album,
    required this.photos,
    required this.onSharePhoto,
  }) : super(key: key);

  Widget _buildPhotoWidget(Photo photo) {
    if (photo.isWebImage) {
      // Web image (Uint8List)
      return Image.memory(
        photo.imageData,
        fit: BoxFit.cover,
      );
    } else {
      // Mobile image (File)
      return Image.file(
        photo.imageData,
        fit: BoxFit.cover,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter photos that belong to this album
    final albumPhotos = photos
        .where((photo) => album.photoIds.contains(photo.id))
        .toList();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(album.name),
      ),
      body: albumPhotos.isEmpty
          ? Center(child: Text('No photos in this album yet'))
          : GridView.builder(
              padding: EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: albumPhotos.length,
              itemBuilder: (context, index) {
                final photo = albumPhotos[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhotoViewScreen(
                          photo: photo,
                          onAddToAlbum: () {}, // We're already in an album
                          onSharePhoto: () => onSharePhoto(photo),
                          buildPhotoWidget: _buildPhotoWidget,
                        ),
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'photo-${photo.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildPhotoWidget(photo),
                    ),
                  ),
                );
              },
            ),
    );
  }
}