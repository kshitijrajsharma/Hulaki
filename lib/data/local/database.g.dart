// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _signingKeyMeta = const VerificationMeta(
    'signingKey',
  );
  @override
  late final GeneratedColumn<String> signingKey = GeneratedColumn<String>(
    'signing_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _agreementKeyMeta = const VerificationMeta(
    'agreementKey',
  );
  @override
  late final GeneratedColumn<String> agreementKey = GeneratedColumn<String>(
    'agreement_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    phone,
    displayName,
    signingKey,
    agreementKey,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Profile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('signing_key')) {
      context.handle(
        _signingKeyMeta,
        signingKey.isAcceptableOrUnknown(data['signing_key']!, _signingKeyMeta),
      );
    }
    if (data.containsKey('agreement_key')) {
      context.handle(
        _agreementKeyMeta,
        agreementKey.isAcceptableOrUnknown(
          data['agreement_key']!,
          _agreementKeyMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      signingKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signing_key'],
      ),
      agreementKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agreement_key'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class Profile extends DataClass implements Insertable<Profile> {
  final String id;
  final String phone;
  final String? displayName;
  final String? signingKey;
  final String? agreementKey;
  final DateTime createdAt;
  const Profile({
    required this.id,
    required this.phone,
    this.displayName,
    this.signingKey,
    this.agreementKey,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['phone'] = Variable<String>(phone);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || signingKey != null) {
      map['signing_key'] = Variable<String>(signingKey);
    }
    if (!nullToAbsent || agreementKey != null) {
      map['agreement_key'] = Variable<String>(agreementKey);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      phone: Value(phone),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      signingKey: signingKey == null && nullToAbsent
          ? const Value.absent()
          : Value(signingKey),
      agreementKey: agreementKey == null && nullToAbsent
          ? const Value.absent()
          : Value(agreementKey),
      createdAt: Value(createdAt),
    );
  }

  factory Profile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<String>(json['id']),
      phone: serializer.fromJson<String>(json['phone']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      signingKey: serializer.fromJson<String?>(json['signingKey']),
      agreementKey: serializer.fromJson<String?>(json['agreementKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'phone': serializer.toJson<String>(phone),
      'displayName': serializer.toJson<String?>(displayName),
      'signingKey': serializer.toJson<String?>(signingKey),
      'agreementKey': serializer.toJson<String?>(agreementKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Profile copyWith({
    String? id,
    String? phone,
    Value<String?> displayName = const Value.absent(),
    Value<String?> signingKey = const Value.absent(),
    Value<String?> agreementKey = const Value.absent(),
    DateTime? createdAt,
  }) => Profile(
    id: id ?? this.id,
    phone: phone ?? this.phone,
    displayName: displayName.present ? displayName.value : this.displayName,
    signingKey: signingKey.present ? signingKey.value : this.signingKey,
    agreementKey: agreementKey.present ? agreementKey.value : this.agreementKey,
    createdAt: createdAt ?? this.createdAt,
  );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      phone: data.phone.present ? data.phone.value : this.phone,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      signingKey: data.signingKey.present
          ? data.signingKey.value
          : this.signingKey,
      agreementKey: data.agreementKey.present
          ? data.agreementKey.value
          : this.agreementKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('phone: $phone, ')
          ..write('displayName: $displayName, ')
          ..write('signingKey: $signingKey, ')
          ..write('agreementKey: $agreementKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, phone, displayName, signingKey, agreementKey, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.phone == this.phone &&
          other.displayName == this.displayName &&
          other.signingKey == this.signingKey &&
          other.agreementKey == this.agreementKey &&
          other.createdAt == this.createdAt);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<String> id;
  final Value<String> phone;
  final Value<String?> displayName;
  final Value<String?> signingKey;
  final Value<String?> agreementKey;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.phone = const Value.absent(),
    this.displayName = const Value.absent(),
    this.signingKey = const Value.absent(),
    this.agreementKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String phone,
    this.displayName = const Value.absent(),
    this.signingKey = const Value.absent(),
    this.agreementKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       phone = Value(phone);
  static Insertable<Profile> custom({
    Expression<String>? id,
    Expression<String>? phone,
    Expression<String>? displayName,
    Expression<String>? signingKey,
    Expression<String>? agreementKey,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (phone != null) 'phone': phone,
      if (displayName != null) 'display_name': displayName,
      if (signingKey != null) 'signing_key': signingKey,
      if (agreementKey != null) 'agreement_key': agreementKey,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? phone,
    Value<String?>? displayName,
    Value<String?>? signingKey,
    Value<String?>? agreementKey,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      displayName: displayName ?? this.displayName,
      signingKey: signingKey ?? this.signingKey,
      agreementKey: agreementKey ?? this.agreementKey,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (signingKey.present) {
      map['signing_key'] = Variable<String>(signingKey.value);
    }
    if (agreementKey.present) {
      map['agreement_key'] = Variable<String>(agreementKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('phone: $phone, ')
          ..write('displayName: $displayName, ')
          ..write('signingKey: $signingKey, ')
          ..write('agreementKey: $agreementKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupsTable extends Groups with TableInfo<$GroupsTable, Group> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encKeyMeta = const VerificationMeta('encKey');
  @override
  late final GeneratedColumn<String> encKey = GeneratedColumn<String>(
    'enc_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aoiGeoJsonMeta = const VerificationMeta(
    'aoiGeoJson',
  );
  @override
  late final GeneratedColumn<String> aoiGeoJson = GeneratedColumn<String>(
    'aoi_geo_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPublicMeta = const VerificationMeta(
    'isPublic',
  );
  @override
  late final GeneratedColumn<bool> isPublic = GeneratedColumn<bool>(
    'is_public',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_public" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _joinApprovalMeta = const VerificationMeta(
    'joinApproval',
  );
  @override
  late final GeneratedColumn<bool> joinApproval = GeneratedColumn<bool>(
    'join_approval',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("join_approval" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _adminRootKeyMeta = const VerificationMeta(
    'adminRootKey',
  );
  @override
  late final GeneratedColumn<String> adminRootKey = GeneratedColumn<String>(
    'admin_root_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allowMemberExportMeta = const VerificationMeta(
    'allowMemberExport',
  );
  @override
  late final GeneratedColumn<bool> allowMemberExport = GeneratedColumn<bool>(
    'allow_member_export',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_member_export" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _allowMemberPlaceMeta = const VerificationMeta(
    'allowMemberPlace',
  );
  @override
  late final GeneratedColumn<bool> allowMemberPlace = GeneratedColumn<bool>(
    'allow_member_place',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_member_place" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _allowOutsideAreaMeta = const VerificationMeta(
    'allowOutsideArea',
  );
  @override
  late final GeneratedColumn<bool> allowOutsideArea = GeneratedColumn<bool>(
    'allow_outside_area',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_outside_area" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _gpsLimitMMeta = const VerificationMeta(
    'gpsLimitM',
  );
  @override
  late final GeneratedColumn<int> gpsLimitM = GeneratedColumn<int>(
    'gps_limit_m',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allowMemberTagsMeta = const VerificationMeta(
    'allowMemberTags',
  );
  @override
  late final GeneratedColumn<bool> allowMemberTags = GeneratedColumn<bool>(
    'allow_member_tags',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_member_tags" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _photoMeta = const VerificationMeta('photo');
  @override
  late final GeneratedColumn<Uint8List> photo = GeneratedColumn<Uint8List>(
    'photo',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoBlobIdMeta = const VerificationMeta(
    'photoBlobId',
  );
  @override
  late final GeneratedColumn<String> photoBlobId = GeneratedColumn<String>(
    'photo_blob_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoKeyMeta = const VerificationMeta(
    'photoKey',
  );
  @override
  late final GeneratedColumn<String> photoKey = GeneratedColumn<String>(
    'photo_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    createdBy,
    encKey,
    aoiGeoJson,
    isPublic,
    joinApproval,
    adminRootKey,
    allowMemberExport,
    allowMemberPlace,
    allowOutsideArea,
    gpsLimitM,
    allowMemberTags,
    photo,
    photoBlobId,
    photoKey,
    createdAt,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<Group> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('enc_key')) {
      context.handle(
        _encKeyMeta,
        encKey.isAcceptableOrUnknown(data['enc_key']!, _encKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_encKeyMeta);
    }
    if (data.containsKey('aoi_geo_json')) {
      context.handle(
        _aoiGeoJsonMeta,
        aoiGeoJson.isAcceptableOrUnknown(
          data['aoi_geo_json']!,
          _aoiGeoJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_public')) {
      context.handle(
        _isPublicMeta,
        isPublic.isAcceptableOrUnknown(data['is_public']!, _isPublicMeta),
      );
    }
    if (data.containsKey('join_approval')) {
      context.handle(
        _joinApprovalMeta,
        joinApproval.isAcceptableOrUnknown(
          data['join_approval']!,
          _joinApprovalMeta,
        ),
      );
    }
    if (data.containsKey('admin_root_key')) {
      context.handle(
        _adminRootKeyMeta,
        adminRootKey.isAcceptableOrUnknown(
          data['admin_root_key']!,
          _adminRootKeyMeta,
        ),
      );
    }
    if (data.containsKey('allow_member_export')) {
      context.handle(
        _allowMemberExportMeta,
        allowMemberExport.isAcceptableOrUnknown(
          data['allow_member_export']!,
          _allowMemberExportMeta,
        ),
      );
    }
    if (data.containsKey('allow_member_place')) {
      context.handle(
        _allowMemberPlaceMeta,
        allowMemberPlace.isAcceptableOrUnknown(
          data['allow_member_place']!,
          _allowMemberPlaceMeta,
        ),
      );
    }
    if (data.containsKey('allow_outside_area')) {
      context.handle(
        _allowOutsideAreaMeta,
        allowOutsideArea.isAcceptableOrUnknown(
          data['allow_outside_area']!,
          _allowOutsideAreaMeta,
        ),
      );
    }
    if (data.containsKey('gps_limit_m')) {
      context.handle(
        _gpsLimitMMeta,
        gpsLimitM.isAcceptableOrUnknown(data['gps_limit_m']!, _gpsLimitMMeta),
      );
    }
    if (data.containsKey('allow_member_tags')) {
      context.handle(
        _allowMemberTagsMeta,
        allowMemberTags.isAcceptableOrUnknown(
          data['allow_member_tags']!,
          _allowMemberTagsMeta,
        ),
      );
    }
    if (data.containsKey('photo')) {
      context.handle(
        _photoMeta,
        photo.isAcceptableOrUnknown(data['photo']!, _photoMeta),
      );
    }
    if (data.containsKey('photo_blob_id')) {
      context.handle(
        _photoBlobIdMeta,
        photoBlobId.isAcceptableOrUnknown(
          data['photo_blob_id']!,
          _photoBlobIdMeta,
        ),
      );
    }
    if (data.containsKey('photo_key')) {
      context.handle(
        _photoKeyMeta,
        photoKey.isAcceptableOrUnknown(data['photo_key']!, _photoKeyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Group map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Group(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      encKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enc_key'],
      )!,
      aoiGeoJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aoi_geo_json'],
      ),
      isPublic: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_public'],
      )!,
      joinApproval: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}join_approval'],
      )!,
      adminRootKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}admin_root_key'],
      ),
      allowMemberExport: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_member_export'],
      )!,
      allowMemberPlace: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_member_place'],
      )!,
      allowOutsideArea: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_outside_area'],
      )!,
      gpsLimitM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gps_limit_m'],
      ),
      allowMemberTags: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_member_tags'],
      )!,
      photo: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}photo'],
      ),
      photoBlobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_blob_id'],
      ),
      photoKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_key'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
    );
  }

  @override
  $GroupsTable createAlias(String alias) {
    return $GroupsTable(attachedDatabase, alias);
  }
}

class Group extends DataClass implements Insertable<Group> {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final String encKey;
  final String? aoiGeoJson;
  final bool isPublic;
  final bool joinApproval;
  final String? adminRootKey;

  /// Moderation controls, all set by an admin and shared through group-meta.
  /// [allowMemberExport] lets non-admins export; [allowMemberPlace] lets them
  /// place points by tapping the map rather than only sending their live fix;
  /// [allowOutsideArea] permits points beyond the mapping area; [gpsLimitM] caps
  /// the accuracy a sent fix may carry, in metres, null meaning no cap;
  /// [allowMemberTags] lets non-admins add, edit and remove the quick tags.
  final bool allowMemberExport;
  final bool allowMemberPlace;
  final bool allowOutsideArea;
  final int? gpsLimitM;
  final bool allowMemberTags;
  final Uint8List? photo;

  /// The cover photo shared with members: its encrypted blob id in object
  /// storage and the base64 key to decrypt it. Both null when there is no
  /// synced photo. The bytes themselves live in [photo] once fetched.
  final String? photoBlobId;
  final String? photoKey;
  final DateTime createdAt;
  final DateTime? archivedAt;
  const Group({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    required this.encKey,
    this.aoiGeoJson,
    required this.isPublic,
    required this.joinApproval,
    this.adminRootKey,
    required this.allowMemberExport,
    required this.allowMemberPlace,
    required this.allowOutsideArea,
    this.gpsLimitM,
    required this.allowMemberTags,
    this.photo,
    this.photoBlobId,
    this.photoKey,
    required this.createdAt,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_by'] = Variable<String>(createdBy);
    map['enc_key'] = Variable<String>(encKey);
    if (!nullToAbsent || aoiGeoJson != null) {
      map['aoi_geo_json'] = Variable<String>(aoiGeoJson);
    }
    map['is_public'] = Variable<bool>(isPublic);
    map['join_approval'] = Variable<bool>(joinApproval);
    if (!nullToAbsent || adminRootKey != null) {
      map['admin_root_key'] = Variable<String>(adminRootKey);
    }
    map['allow_member_export'] = Variable<bool>(allowMemberExport);
    map['allow_member_place'] = Variable<bool>(allowMemberPlace);
    map['allow_outside_area'] = Variable<bool>(allowOutsideArea);
    if (!nullToAbsent || gpsLimitM != null) {
      map['gps_limit_m'] = Variable<int>(gpsLimitM);
    }
    map['allow_member_tags'] = Variable<bool>(allowMemberTags);
    if (!nullToAbsent || photo != null) {
      map['photo'] = Variable<Uint8List>(photo);
    }
    if (!nullToAbsent || photoBlobId != null) {
      map['photo_blob_id'] = Variable<String>(photoBlobId);
    }
    if (!nullToAbsent || photoKey != null) {
      map['photo_key'] = Variable<String>(photoKey);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    return map;
  }

  GroupsCompanion toCompanion(bool nullToAbsent) {
    return GroupsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdBy: Value(createdBy),
      encKey: Value(encKey),
      aoiGeoJson: aoiGeoJson == null && nullToAbsent
          ? const Value.absent()
          : Value(aoiGeoJson),
      isPublic: Value(isPublic),
      joinApproval: Value(joinApproval),
      adminRootKey: adminRootKey == null && nullToAbsent
          ? const Value.absent()
          : Value(adminRootKey),
      allowMemberExport: Value(allowMemberExport),
      allowMemberPlace: Value(allowMemberPlace),
      allowOutsideArea: Value(allowOutsideArea),
      gpsLimitM: gpsLimitM == null && nullToAbsent
          ? const Value.absent()
          : Value(gpsLimitM),
      allowMemberTags: Value(allowMemberTags),
      photo: photo == null && nullToAbsent
          ? const Value.absent()
          : Value(photo),
      photoBlobId: photoBlobId == null && nullToAbsent
          ? const Value.absent()
          : Value(photoBlobId),
      photoKey: photoKey == null && nullToAbsent
          ? const Value.absent()
          : Value(photoKey),
      createdAt: Value(createdAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
    );
  }

  factory Group.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Group(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      encKey: serializer.fromJson<String>(json['encKey']),
      aoiGeoJson: serializer.fromJson<String?>(json['aoiGeoJson']),
      isPublic: serializer.fromJson<bool>(json['isPublic']),
      joinApproval: serializer.fromJson<bool>(json['joinApproval']),
      adminRootKey: serializer.fromJson<String?>(json['adminRootKey']),
      allowMemberExport: serializer.fromJson<bool>(json['allowMemberExport']),
      allowMemberPlace: serializer.fromJson<bool>(json['allowMemberPlace']),
      allowOutsideArea: serializer.fromJson<bool>(json['allowOutsideArea']),
      gpsLimitM: serializer.fromJson<int?>(json['gpsLimitM']),
      allowMemberTags: serializer.fromJson<bool>(json['allowMemberTags']),
      photo: serializer.fromJson<Uint8List?>(json['photo']),
      photoBlobId: serializer.fromJson<String?>(json['photoBlobId']),
      photoKey: serializer.fromJson<String?>(json['photoKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'createdBy': serializer.toJson<String>(createdBy),
      'encKey': serializer.toJson<String>(encKey),
      'aoiGeoJson': serializer.toJson<String?>(aoiGeoJson),
      'isPublic': serializer.toJson<bool>(isPublic),
      'joinApproval': serializer.toJson<bool>(joinApproval),
      'adminRootKey': serializer.toJson<String?>(adminRootKey),
      'allowMemberExport': serializer.toJson<bool>(allowMemberExport),
      'allowMemberPlace': serializer.toJson<bool>(allowMemberPlace),
      'allowOutsideArea': serializer.toJson<bool>(allowOutsideArea),
      'gpsLimitM': serializer.toJson<int?>(gpsLimitM),
      'allowMemberTags': serializer.toJson<bool>(allowMemberTags),
      'photo': serializer.toJson<Uint8List?>(photo),
      'photoBlobId': serializer.toJson<String?>(photoBlobId),
      'photoKey': serializer.toJson<String?>(photoKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
    };
  }

  Group copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    String? createdBy,
    String? encKey,
    Value<String?> aoiGeoJson = const Value.absent(),
    bool? isPublic,
    bool? joinApproval,
    Value<String?> adminRootKey = const Value.absent(),
    bool? allowMemberExport,
    bool? allowMemberPlace,
    bool? allowOutsideArea,
    Value<int?> gpsLimitM = const Value.absent(),
    bool? allowMemberTags,
    Value<Uint8List?> photo = const Value.absent(),
    Value<String?> photoBlobId = const Value.absent(),
    Value<String?> photoKey = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> archivedAt = const Value.absent(),
  }) => Group(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    createdBy: createdBy ?? this.createdBy,
    encKey: encKey ?? this.encKey,
    aoiGeoJson: aoiGeoJson.present ? aoiGeoJson.value : this.aoiGeoJson,
    isPublic: isPublic ?? this.isPublic,
    joinApproval: joinApproval ?? this.joinApproval,
    adminRootKey: adminRootKey.present ? adminRootKey.value : this.adminRootKey,
    allowMemberExport: allowMemberExport ?? this.allowMemberExport,
    allowMemberPlace: allowMemberPlace ?? this.allowMemberPlace,
    allowOutsideArea: allowOutsideArea ?? this.allowOutsideArea,
    gpsLimitM: gpsLimitM.present ? gpsLimitM.value : this.gpsLimitM,
    allowMemberTags: allowMemberTags ?? this.allowMemberTags,
    photo: photo.present ? photo.value : this.photo,
    photoBlobId: photoBlobId.present ? photoBlobId.value : this.photoBlobId,
    photoKey: photoKey.present ? photoKey.value : this.photoKey,
    createdAt: createdAt ?? this.createdAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  Group copyWithCompanion(GroupsCompanion data) {
    return Group(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      encKey: data.encKey.present ? data.encKey.value : this.encKey,
      aoiGeoJson: data.aoiGeoJson.present
          ? data.aoiGeoJson.value
          : this.aoiGeoJson,
      isPublic: data.isPublic.present ? data.isPublic.value : this.isPublic,
      joinApproval: data.joinApproval.present
          ? data.joinApproval.value
          : this.joinApproval,
      adminRootKey: data.adminRootKey.present
          ? data.adminRootKey.value
          : this.adminRootKey,
      allowMemberExport: data.allowMemberExport.present
          ? data.allowMemberExport.value
          : this.allowMemberExport,
      allowMemberPlace: data.allowMemberPlace.present
          ? data.allowMemberPlace.value
          : this.allowMemberPlace,
      allowOutsideArea: data.allowOutsideArea.present
          ? data.allowOutsideArea.value
          : this.allowOutsideArea,
      gpsLimitM: data.gpsLimitM.present ? data.gpsLimitM.value : this.gpsLimitM,
      allowMemberTags: data.allowMemberTags.present
          ? data.allowMemberTags.value
          : this.allowMemberTags,
      photo: data.photo.present ? data.photo.value : this.photo,
      photoBlobId: data.photoBlobId.present
          ? data.photoBlobId.value
          : this.photoBlobId,
      photoKey: data.photoKey.present ? data.photoKey.value : this.photoKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Group(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdBy: $createdBy, ')
          ..write('encKey: $encKey, ')
          ..write('aoiGeoJson: $aoiGeoJson, ')
          ..write('isPublic: $isPublic, ')
          ..write('joinApproval: $joinApproval, ')
          ..write('adminRootKey: $adminRootKey, ')
          ..write('allowMemberExport: $allowMemberExport, ')
          ..write('allowMemberPlace: $allowMemberPlace, ')
          ..write('allowOutsideArea: $allowOutsideArea, ')
          ..write('gpsLimitM: $gpsLimitM, ')
          ..write('allowMemberTags: $allowMemberTags, ')
          ..write('photo: $photo, ')
          ..write('photoBlobId: $photoBlobId, ')
          ..write('photoKey: $photoKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    createdBy,
    encKey,
    aoiGeoJson,
    isPublic,
    joinApproval,
    adminRootKey,
    allowMemberExport,
    allowMemberPlace,
    allowOutsideArea,
    gpsLimitM,
    allowMemberTags,
    $driftBlobEquality.hash(photo),
    photoBlobId,
    photoKey,
    createdAt,
    archivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Group &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.createdBy == this.createdBy &&
          other.encKey == this.encKey &&
          other.aoiGeoJson == this.aoiGeoJson &&
          other.isPublic == this.isPublic &&
          other.joinApproval == this.joinApproval &&
          other.adminRootKey == this.adminRootKey &&
          other.allowMemberExport == this.allowMemberExport &&
          other.allowMemberPlace == this.allowMemberPlace &&
          other.allowOutsideArea == this.allowOutsideArea &&
          other.gpsLimitM == this.gpsLimitM &&
          other.allowMemberTags == this.allowMemberTags &&
          $driftBlobEquality.equals(other.photo, this.photo) &&
          other.photoBlobId == this.photoBlobId &&
          other.photoKey == this.photoKey &&
          other.createdAt == this.createdAt &&
          other.archivedAt == this.archivedAt);
}

class GroupsCompanion extends UpdateCompanion<Group> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> createdBy;
  final Value<String> encKey;
  final Value<String?> aoiGeoJson;
  final Value<bool> isPublic;
  final Value<bool> joinApproval;
  final Value<String?> adminRootKey;
  final Value<bool> allowMemberExport;
  final Value<bool> allowMemberPlace;
  final Value<bool> allowOutsideArea;
  final Value<int?> gpsLimitM;
  final Value<bool> allowMemberTags;
  final Value<Uint8List?> photo;
  final Value<String?> photoBlobId;
  final Value<String?> photoKey;
  final Value<DateTime> createdAt;
  final Value<DateTime?> archivedAt;
  final Value<int> rowid;
  const GroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.encKey = const Value.absent(),
    this.aoiGeoJson = const Value.absent(),
    this.isPublic = const Value.absent(),
    this.joinApproval = const Value.absent(),
    this.adminRootKey = const Value.absent(),
    this.allowMemberExport = const Value.absent(),
    this.allowMemberPlace = const Value.absent(),
    this.allowOutsideArea = const Value.absent(),
    this.gpsLimitM = const Value.absent(),
    this.allowMemberTags = const Value.absent(),
    this.photo = const Value.absent(),
    this.photoBlobId = const Value.absent(),
    this.photoKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required String createdBy,
    required String encKey,
    this.aoiGeoJson = const Value.absent(),
    this.isPublic = const Value.absent(),
    this.joinApproval = const Value.absent(),
    this.adminRootKey = const Value.absent(),
    this.allowMemberExport = const Value.absent(),
    this.allowMemberPlace = const Value.absent(),
    this.allowOutsideArea = const Value.absent(),
    this.gpsLimitM = const Value.absent(),
    this.allowMemberTags = const Value.absent(),
    this.photo = const Value.absent(),
    this.photoBlobId = const Value.absent(),
    this.photoKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdBy = Value(createdBy),
       encKey = Value(encKey);
  static Insertable<Group> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? createdBy,
    Expression<String>? encKey,
    Expression<String>? aoiGeoJson,
    Expression<bool>? isPublic,
    Expression<bool>? joinApproval,
    Expression<String>? adminRootKey,
    Expression<bool>? allowMemberExport,
    Expression<bool>? allowMemberPlace,
    Expression<bool>? allowOutsideArea,
    Expression<int>? gpsLimitM,
    Expression<bool>? allowMemberTags,
    Expression<Uint8List>? photo,
    Expression<String>? photoBlobId,
    Expression<String>? photoKey,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (createdBy != null) 'created_by': createdBy,
      if (encKey != null) 'enc_key': encKey,
      if (aoiGeoJson != null) 'aoi_geo_json': aoiGeoJson,
      if (isPublic != null) 'is_public': isPublic,
      if (joinApproval != null) 'join_approval': joinApproval,
      if (adminRootKey != null) 'admin_root_key': adminRootKey,
      if (allowMemberExport != null) 'allow_member_export': allowMemberExport,
      if (allowMemberPlace != null) 'allow_member_place': allowMemberPlace,
      if (allowOutsideArea != null) 'allow_outside_area': allowOutsideArea,
      if (gpsLimitM != null) 'gps_limit_m': gpsLimitM,
      if (allowMemberTags != null) 'allow_member_tags': allowMemberTags,
      if (photo != null) 'photo': photo,
      if (photoBlobId != null) 'photo_blob_id': photoBlobId,
      if (photoKey != null) 'photo_key': photoKey,
      if (createdAt != null) 'created_at': createdAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String>? createdBy,
    Value<String>? encKey,
    Value<String?>? aoiGeoJson,
    Value<bool>? isPublic,
    Value<bool>? joinApproval,
    Value<String?>? adminRootKey,
    Value<bool>? allowMemberExport,
    Value<bool>? allowMemberPlace,
    Value<bool>? allowOutsideArea,
    Value<int?>? gpsLimitM,
    Value<bool>? allowMemberTags,
    Value<Uint8List?>? photo,
    Value<String?>? photoBlobId,
    Value<String?>? photoKey,
    Value<DateTime>? createdAt,
    Value<DateTime?>? archivedAt,
    Value<int>? rowid,
  }) {
    return GroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      encKey: encKey ?? this.encKey,
      aoiGeoJson: aoiGeoJson ?? this.aoiGeoJson,
      isPublic: isPublic ?? this.isPublic,
      joinApproval: joinApproval ?? this.joinApproval,
      adminRootKey: adminRootKey ?? this.adminRootKey,
      allowMemberExport: allowMemberExport ?? this.allowMemberExport,
      allowMemberPlace: allowMemberPlace ?? this.allowMemberPlace,
      allowOutsideArea: allowOutsideArea ?? this.allowOutsideArea,
      gpsLimitM: gpsLimitM ?? this.gpsLimitM,
      allowMemberTags: allowMemberTags ?? this.allowMemberTags,
      photo: photo ?? this.photo,
      photoBlobId: photoBlobId ?? this.photoBlobId,
      photoKey: photoKey ?? this.photoKey,
      createdAt: createdAt ?? this.createdAt,
      archivedAt: archivedAt ?? this.archivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (encKey.present) {
      map['enc_key'] = Variable<String>(encKey.value);
    }
    if (aoiGeoJson.present) {
      map['aoi_geo_json'] = Variable<String>(aoiGeoJson.value);
    }
    if (isPublic.present) {
      map['is_public'] = Variable<bool>(isPublic.value);
    }
    if (joinApproval.present) {
      map['join_approval'] = Variable<bool>(joinApproval.value);
    }
    if (adminRootKey.present) {
      map['admin_root_key'] = Variable<String>(adminRootKey.value);
    }
    if (allowMemberExport.present) {
      map['allow_member_export'] = Variable<bool>(allowMemberExport.value);
    }
    if (allowMemberPlace.present) {
      map['allow_member_place'] = Variable<bool>(allowMemberPlace.value);
    }
    if (allowOutsideArea.present) {
      map['allow_outside_area'] = Variable<bool>(allowOutsideArea.value);
    }
    if (gpsLimitM.present) {
      map['gps_limit_m'] = Variable<int>(gpsLimitM.value);
    }
    if (allowMemberTags.present) {
      map['allow_member_tags'] = Variable<bool>(allowMemberTags.value);
    }
    if (photo.present) {
      map['photo'] = Variable<Uint8List>(photo.value);
    }
    if (photoBlobId.present) {
      map['photo_blob_id'] = Variable<String>(photoBlobId.value);
    }
    if (photoKey.present) {
      map['photo_key'] = Variable<String>(photoKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdBy: $createdBy, ')
          ..write('encKey: $encKey, ')
          ..write('aoiGeoJson: $aoiGeoJson, ')
          ..write('isPublic: $isPublic, ')
          ..write('joinApproval: $joinApproval, ')
          ..write('adminRootKey: $adminRootKey, ')
          ..write('allowMemberExport: $allowMemberExport, ')
          ..write('allowMemberPlace: $allowMemberPlace, ')
          ..write('allowOutsideArea: $allowOutsideArea, ')
          ..write('gpsLimitM: $gpsLimitM, ')
          ..write('allowMemberTags: $allowMemberTags, ')
          ..write('photo: $photo, ')
          ..write('photoBlobId: $photoBlobId, ')
          ..write('photoKey: $photoKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HotKeysTable extends HotKeys with TableInfo<$HotKeysTable, HotKey> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HotKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id)',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    label,
    colorValue,
    iconName,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hot_keys';
  @override
  VerificationContext validateIntegrity(
    Insertable<HotKey> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HotKey map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HotKey(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $HotKeysTable createAlias(String alias) {
    return $HotKeysTable(attachedDatabase, alias);
  }
}

class HotKey extends DataClass implements Insertable<HotKey> {
  final String id;
  final String groupId;
  final String label;
  final int colorValue;
  final String? iconName;
  final int position;
  const HotKey({
    required this.id,
    required this.groupId,
    required this.label,
    required this.colorValue,
    this.iconName,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['label'] = Variable<String>(label);
    map['color_value'] = Variable<int>(colorValue);
    if (!nullToAbsent || iconName != null) {
      map['icon_name'] = Variable<String>(iconName);
    }
    map['position'] = Variable<int>(position);
    return map;
  }

  HotKeysCompanion toCompanion(bool nullToAbsent) {
    return HotKeysCompanion(
      id: Value(id),
      groupId: Value(groupId),
      label: Value(label),
      colorValue: Value(colorValue),
      iconName: iconName == null && nullToAbsent
          ? const Value.absent()
          : Value(iconName),
      position: Value(position),
    );
  }

  factory HotKey.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HotKey(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      label: serializer.fromJson<String>(json['label']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      iconName: serializer.fromJson<String?>(json['iconName']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'label': serializer.toJson<String>(label),
      'colorValue': serializer.toJson<int>(colorValue),
      'iconName': serializer.toJson<String?>(iconName),
      'position': serializer.toJson<int>(position),
    };
  }

  HotKey copyWith({
    String? id,
    String? groupId,
    String? label,
    int? colorValue,
    Value<String?> iconName = const Value.absent(),
    int? position,
  }) => HotKey(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    label: label ?? this.label,
    colorValue: colorValue ?? this.colorValue,
    iconName: iconName.present ? iconName.value : this.iconName,
    position: position ?? this.position,
  );
  HotKey copyWithCompanion(HotKeysCompanion data) {
    return HotKey(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      label: data.label.present ? data.label.value : this.label,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HotKey(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('label: $label, ')
          ..write('colorValue: $colorValue, ')
          ..write('iconName: $iconName, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, groupId, label, colorValue, iconName, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HotKey &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.label == this.label &&
          other.colorValue == this.colorValue &&
          other.iconName == this.iconName &&
          other.position == this.position);
}

class HotKeysCompanion extends UpdateCompanion<HotKey> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> label;
  final Value<int> colorValue;
  final Value<String?> iconName;
  final Value<int> position;
  final Value<int> rowid;
  const HotKeysCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.label = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.iconName = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HotKeysCompanion.insert({
    required String id,
    required String groupId,
    required String label,
    required int colorValue,
    this.iconName = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       label = Value(label),
       colorValue = Value(colorValue);
  static Insertable<HotKey> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? label,
    Expression<int>? colorValue,
    Expression<String>? iconName,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (label != null) 'label': label,
      if (colorValue != null) 'color_value': colorValue,
      if (iconName != null) 'icon_name': iconName,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HotKeysCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? label,
    Value<int>? colorValue,
    Value<String?>? iconName,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return HotKeysCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      label: label ?? this.label,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HotKeysCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('label: $label, ')
          ..write('colorValue: $colorValue, ')
          ..write('iconName: $iconName, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupMembersTable extends GroupMembers
    with TableInfo<$GroupMembersTable, GroupMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id)',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('member'),
  );
  static const VerificationMeta _joinedAtMeta = const VerificationMeta(
    'joinedAt',
  );
  @override
  late final GeneratedColumn<DateTime> joinedAt = GeneratedColumn<DateTime>(
    'joined_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [groupId, profileId, role, joinedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('joined_at')) {
      context.handle(
        _joinedAtMeta,
        joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, profileId};
  @override
  GroupMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupMember(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      joinedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}joined_at'],
      )!,
    );
  }

  @override
  $GroupMembersTable createAlias(String alias) {
    return $GroupMembersTable(attachedDatabase, alias);
  }
}

class GroupMember extends DataClass implements Insertable<GroupMember> {
  final String groupId;
  final String profileId;
  final String role;
  final DateTime joinedAt;
  const GroupMember({
    required this.groupId,
    required this.profileId,
    required this.role,
    required this.joinedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['profile_id'] = Variable<String>(profileId);
    map['role'] = Variable<String>(role);
    map['joined_at'] = Variable<DateTime>(joinedAt);
    return map;
  }

  GroupMembersCompanion toCompanion(bool nullToAbsent) {
    return GroupMembersCompanion(
      groupId: Value(groupId),
      profileId: Value(profileId),
      role: Value(role),
      joinedAt: Value(joinedAt),
    );
  }

  factory GroupMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupMember(
      groupId: serializer.fromJson<String>(json['groupId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      role: serializer.fromJson<String>(json['role']),
      joinedAt: serializer.fromJson<DateTime>(json['joinedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'profileId': serializer.toJson<String>(profileId),
      'role': serializer.toJson<String>(role),
      'joinedAt': serializer.toJson<DateTime>(joinedAt),
    };
  }

  GroupMember copyWith({
    String? groupId,
    String? profileId,
    String? role,
    DateTime? joinedAt,
  }) => GroupMember(
    groupId: groupId ?? this.groupId,
    profileId: profileId ?? this.profileId,
    role: role ?? this.role,
    joinedAt: joinedAt ?? this.joinedAt,
  );
  GroupMember copyWithCompanion(GroupMembersCompanion data) {
    return GroupMember(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      role: data.role.present ? data.role.value : this.role,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupMember(')
          ..write('groupId: $groupId, ')
          ..write('profileId: $profileId, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, profileId, role, joinedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupMember &&
          other.groupId == this.groupId &&
          other.profileId == this.profileId &&
          other.role == this.role &&
          other.joinedAt == this.joinedAt);
}

class GroupMembersCompanion extends UpdateCompanion<GroupMember> {
  final Value<String> groupId;
  final Value<String> profileId;
  final Value<String> role;
  final Value<DateTime> joinedAt;
  final Value<int> rowid;
  const GroupMembersCompanion({
    this.groupId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.role = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupMembersCompanion.insert({
    required String groupId,
    required String profileId,
    this.role = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId),
       profileId = Value(profileId);
  static Insertable<GroupMember> custom({
    Expression<String>? groupId,
    Expression<String>? profileId,
    Expression<String>? role,
    Expression<DateTime>? joinedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (profileId != null) 'profile_id': profileId,
      if (role != null) 'role': role,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupMembersCompanion copyWith({
    Value<String>? groupId,
    Value<String>? profileId,
    Value<String>? role,
    Value<DateTime>? joinedAt,
    Value<int>? rowid,
  }) {
    return GroupMembersCompanion(
      groupId: groupId ?? this.groupId,
      profileId: profileId ?? this.profileId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<DateTime>(joinedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupMembersCompanion(')
          ..write('groupId: $groupId, ')
          ..write('profileId: $profileId, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id)',
    ),
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accuracyMMeta = const VerificationMeta(
    'accuracyM',
  );
  @override
  late final GeneratedColumn<double> accuracyM = GeneratedColumn<double>(
    'accuracy_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _altitudeMMeta = const VerificationMeta(
    'altitudeM',
  );
  @override
  late final GeneratedColumn<double> altitudeM = GeneratedColumn<double>(
    'altitude_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headingDegMeta = const VerificationMeta(
    'headingDeg',
  );
  @override
  late final GeneratedColumn<double> headingDeg = GeneratedColumn<double>(
    'heading_deg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationPendingMeta = const VerificationMeta(
    'locationPending',
  );
  @override
  late final GeneratedColumn<bool> locationPending = GeneratedColumn<bool>(
    'location_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("location_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
    'media_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaMimeMeta = const VerificationMeta(
    'mediaMime',
  );
  @override
  late final GeneratedColumn<String> mediaMime = GeneratedColumn<String>(
    'media_mime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaKeyMeta = const VerificationMeta(
    'mediaKey',
  );
  @override
  late final GeneratedColumn<String> mediaKey = GeneratedColumn<String>(
    'media_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToIdMeta = const VerificationMeta(
    'replyToId',
  );
  @override
  late final GeneratedColumn<String> replyToId = GeneratedColumn<String>(
    'reply_to_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editedAtMeta = const VerificationMeta(
    'editedAt',
  );
  @override
  late final GeneratedColumn<DateTime> editedAt = GeneratedColumn<DateTime>(
    'edited_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sendStateMeta = const VerificationMeta(
    'sendState',
  );
  @override
  late final GeneratedColumn<String> sendState = GeneratedColumn<String>(
    'send_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _remoteSeqMeta = const VerificationMeta(
    'remoteSeq',
  );
  @override
  late final GeneratedColumn<int> remoteSeq = GeneratedColumn<int>(
    'remote_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _anonymousMeta = const VerificationMeta(
    'anonymous',
  );
  @override
  late final GeneratedColumn<bool> anonymous = GeneratedColumn<bool>(
    'anonymous',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("anonymous" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    senderId,
    kind,
    body,
    tagId,
    lat,
    lng,
    accuracyM,
    altitudeM,
    headingDeg,
    locationPending,
    mediaId,
    mediaMime,
    mediaKey,
    replyToId,
    createdAt,
    editedAt,
    deletedAt,
    sendState,
    remoteSeq,
    anonymous,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    }
    if (data.containsKey('accuracy_m')) {
      context.handle(
        _accuracyMMeta,
        accuracyM.isAcceptableOrUnknown(data['accuracy_m']!, _accuracyMMeta),
      );
    }
    if (data.containsKey('altitude_m')) {
      context.handle(
        _altitudeMMeta,
        altitudeM.isAcceptableOrUnknown(data['altitude_m']!, _altitudeMMeta),
      );
    }
    if (data.containsKey('heading_deg')) {
      context.handle(
        _headingDegMeta,
        headingDeg.isAcceptableOrUnknown(data['heading_deg']!, _headingDegMeta),
      );
    }
    if (data.containsKey('location_pending')) {
      context.handle(
        _locationPendingMeta,
        locationPending.isAcceptableOrUnknown(
          data['location_pending']!,
          _locationPendingMeta,
        ),
      );
    }
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    }
    if (data.containsKey('media_mime')) {
      context.handle(
        _mediaMimeMeta,
        mediaMime.isAcceptableOrUnknown(data['media_mime']!, _mediaMimeMeta),
      );
    }
    if (data.containsKey('media_key')) {
      context.handle(
        _mediaKeyMeta,
        mediaKey.isAcceptableOrUnknown(data['media_key']!, _mediaKeyMeta),
      );
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
        _replyToIdMeta,
        replyToId.isAcceptableOrUnknown(data['reply_to_id']!, _replyToIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('edited_at')) {
      context.handle(
        _editedAtMeta,
        editedAt.isAcceptableOrUnknown(data['edited_at']!, _editedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('send_state')) {
      context.handle(
        _sendStateMeta,
        sendState.isAcceptableOrUnknown(data['send_state']!, _sendStateMeta),
      );
    }
    if (data.containsKey('remote_seq')) {
      context.handle(
        _remoteSeqMeta,
        remoteSeq.isAcceptableOrUnknown(data['remote_seq']!, _remoteSeqMeta),
      );
    }
    if (data.containsKey('anonymous')) {
      context.handle(
        _anonymousMeta,
        anonymous.isAcceptableOrUnknown(data['anonymous']!, _anonymousMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      ),
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      ),
      accuracyM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy_m'],
      ),
      altitudeM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}altitude_m'],
      ),
      headingDeg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}heading_deg'],
      ),
      locationPending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}location_pending'],
      )!,
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_id'],
      ),
      mediaMime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_mime'],
      ),
      mediaKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_key'],
      ),
      replyToId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      editedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}edited_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      sendState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}send_state'],
      )!,
      remoteSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_seq'],
      ),
      anonymous: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}anonymous'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final String id;
  final String groupId;
  final String senderId;
  final String kind;
  final String? body;
  final String? tagId;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final double? altitudeM;
  final double? headingDeg;
  final bool locationPending;
  final String? mediaId;
  final String? mediaMime;
  final String? mediaKey;
  final String? replyToId;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String sendState;
  final int? remoteSeq;
  final bool anonymous;
  const Message({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.kind,
    this.body,
    this.tagId,
    this.lat,
    this.lng,
    this.accuracyM,
    this.altitudeM,
    this.headingDeg,
    required this.locationPending,
    this.mediaId,
    this.mediaMime,
    this.mediaKey,
    this.replyToId,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    required this.sendState,
    this.remoteSeq,
    required this.anonymous,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['sender_id'] = Variable<String>(senderId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || tagId != null) {
      map['tag_id'] = Variable<String>(tagId);
    }
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    if (!nullToAbsent || accuracyM != null) {
      map['accuracy_m'] = Variable<double>(accuracyM);
    }
    if (!nullToAbsent || altitudeM != null) {
      map['altitude_m'] = Variable<double>(altitudeM);
    }
    if (!nullToAbsent || headingDeg != null) {
      map['heading_deg'] = Variable<double>(headingDeg);
    }
    map['location_pending'] = Variable<bool>(locationPending);
    if (!nullToAbsent || mediaId != null) {
      map['media_id'] = Variable<String>(mediaId);
    }
    if (!nullToAbsent || mediaMime != null) {
      map['media_mime'] = Variable<String>(mediaMime);
    }
    if (!nullToAbsent || mediaKey != null) {
      map['media_key'] = Variable<String>(mediaKey);
    }
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<String>(replyToId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || editedAt != null) {
      map['edited_at'] = Variable<DateTime>(editedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['send_state'] = Variable<String>(sendState);
    if (!nullToAbsent || remoteSeq != null) {
      map['remote_seq'] = Variable<int>(remoteSeq);
    }
    map['anonymous'] = Variable<bool>(anonymous);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      groupId: Value(groupId),
      senderId: Value(senderId),
      kind: Value(kind),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      tagId: tagId == null && nullToAbsent
          ? const Value.absent()
          : Value(tagId),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
      accuracyM: accuracyM == null && nullToAbsent
          ? const Value.absent()
          : Value(accuracyM),
      altitudeM: altitudeM == null && nullToAbsent
          ? const Value.absent()
          : Value(altitudeM),
      headingDeg: headingDeg == null && nullToAbsent
          ? const Value.absent()
          : Value(headingDeg),
      locationPending: Value(locationPending),
      mediaId: mediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaId),
      mediaMime: mediaMime == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaMime),
      mediaKey: mediaKey == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaKey),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      createdAt: Value(createdAt),
      editedAt: editedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(editedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      sendState: Value(sendState),
      remoteSeq: remoteSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteSeq),
      anonymous: Value(anonymous),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      kind: serializer.fromJson<String>(json['kind']),
      body: serializer.fromJson<String?>(json['body']),
      tagId: serializer.fromJson<String?>(json['tagId']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
      accuracyM: serializer.fromJson<double?>(json['accuracyM']),
      altitudeM: serializer.fromJson<double?>(json['altitudeM']),
      headingDeg: serializer.fromJson<double?>(json['headingDeg']),
      locationPending: serializer.fromJson<bool>(json['locationPending']),
      mediaId: serializer.fromJson<String?>(json['mediaId']),
      mediaMime: serializer.fromJson<String?>(json['mediaMime']),
      mediaKey: serializer.fromJson<String?>(json['mediaKey']),
      replyToId: serializer.fromJson<String?>(json['replyToId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      editedAt: serializer.fromJson<DateTime?>(json['editedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      sendState: serializer.fromJson<String>(json['sendState']),
      remoteSeq: serializer.fromJson<int?>(json['remoteSeq']),
      anonymous: serializer.fromJson<bool>(json['anonymous']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'senderId': serializer.toJson<String>(senderId),
      'kind': serializer.toJson<String>(kind),
      'body': serializer.toJson<String?>(body),
      'tagId': serializer.toJson<String?>(tagId),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
      'accuracyM': serializer.toJson<double?>(accuracyM),
      'altitudeM': serializer.toJson<double?>(altitudeM),
      'headingDeg': serializer.toJson<double?>(headingDeg),
      'locationPending': serializer.toJson<bool>(locationPending),
      'mediaId': serializer.toJson<String?>(mediaId),
      'mediaMime': serializer.toJson<String?>(mediaMime),
      'mediaKey': serializer.toJson<String?>(mediaKey),
      'replyToId': serializer.toJson<String?>(replyToId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'editedAt': serializer.toJson<DateTime?>(editedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'sendState': serializer.toJson<String>(sendState),
      'remoteSeq': serializer.toJson<int?>(remoteSeq),
      'anonymous': serializer.toJson<bool>(anonymous),
    };
  }

  Message copyWith({
    String? id,
    String? groupId,
    String? senderId,
    String? kind,
    Value<String?> body = const Value.absent(),
    Value<String?> tagId = const Value.absent(),
    Value<double?> lat = const Value.absent(),
    Value<double?> lng = const Value.absent(),
    Value<double?> accuracyM = const Value.absent(),
    Value<double?> altitudeM = const Value.absent(),
    Value<double?> headingDeg = const Value.absent(),
    bool? locationPending,
    Value<String?> mediaId = const Value.absent(),
    Value<String?> mediaMime = const Value.absent(),
    Value<String?> mediaKey = const Value.absent(),
    Value<String?> replyToId = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> editedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    String? sendState,
    Value<int?> remoteSeq = const Value.absent(),
    bool? anonymous,
  }) => Message(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    senderId: senderId ?? this.senderId,
    kind: kind ?? this.kind,
    body: body.present ? body.value : this.body,
    tagId: tagId.present ? tagId.value : this.tagId,
    lat: lat.present ? lat.value : this.lat,
    lng: lng.present ? lng.value : this.lng,
    accuracyM: accuracyM.present ? accuracyM.value : this.accuracyM,
    altitudeM: altitudeM.present ? altitudeM.value : this.altitudeM,
    headingDeg: headingDeg.present ? headingDeg.value : this.headingDeg,
    locationPending: locationPending ?? this.locationPending,
    mediaId: mediaId.present ? mediaId.value : this.mediaId,
    mediaMime: mediaMime.present ? mediaMime.value : this.mediaMime,
    mediaKey: mediaKey.present ? mediaKey.value : this.mediaKey,
    replyToId: replyToId.present ? replyToId.value : this.replyToId,
    createdAt: createdAt ?? this.createdAt,
    editedAt: editedAt.present ? editedAt.value : this.editedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    sendState: sendState ?? this.sendState,
    remoteSeq: remoteSeq.present ? remoteSeq.value : this.remoteSeq,
    anonymous: anonymous ?? this.anonymous,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      kind: data.kind.present ? data.kind.value : this.kind,
      body: data.body.present ? data.body.value : this.body,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      accuracyM: data.accuracyM.present ? data.accuracyM.value : this.accuracyM,
      altitudeM: data.altitudeM.present ? data.altitudeM.value : this.altitudeM,
      headingDeg: data.headingDeg.present
          ? data.headingDeg.value
          : this.headingDeg,
      locationPending: data.locationPending.present
          ? data.locationPending.value
          : this.locationPending,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      mediaMime: data.mediaMime.present ? data.mediaMime.value : this.mediaMime,
      mediaKey: data.mediaKey.present ? data.mediaKey.value : this.mediaKey,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      editedAt: data.editedAt.present ? data.editedAt.value : this.editedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      sendState: data.sendState.present ? data.sendState.value : this.sendState,
      remoteSeq: data.remoteSeq.present ? data.remoteSeq.value : this.remoteSeq,
      anonymous: data.anonymous.present ? data.anonymous.value : this.anonymous,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('senderId: $senderId, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('tagId: $tagId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('altitudeM: $altitudeM, ')
          ..write('headingDeg: $headingDeg, ')
          ..write('locationPending: $locationPending, ')
          ..write('mediaId: $mediaId, ')
          ..write('mediaMime: $mediaMime, ')
          ..write('mediaKey: $mediaKey, ')
          ..write('replyToId: $replyToId, ')
          ..write('createdAt: $createdAt, ')
          ..write('editedAt: $editedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('sendState: $sendState, ')
          ..write('remoteSeq: $remoteSeq, ')
          ..write('anonymous: $anonymous')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    groupId,
    senderId,
    kind,
    body,
    tagId,
    lat,
    lng,
    accuracyM,
    altitudeM,
    headingDeg,
    locationPending,
    mediaId,
    mediaMime,
    mediaKey,
    replyToId,
    createdAt,
    editedAt,
    deletedAt,
    sendState,
    remoteSeq,
    anonymous,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.senderId == this.senderId &&
          other.kind == this.kind &&
          other.body == this.body &&
          other.tagId == this.tagId &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.accuracyM == this.accuracyM &&
          other.altitudeM == this.altitudeM &&
          other.headingDeg == this.headingDeg &&
          other.locationPending == this.locationPending &&
          other.mediaId == this.mediaId &&
          other.mediaMime == this.mediaMime &&
          other.mediaKey == this.mediaKey &&
          other.replyToId == this.replyToId &&
          other.createdAt == this.createdAt &&
          other.editedAt == this.editedAt &&
          other.deletedAt == this.deletedAt &&
          other.sendState == this.sendState &&
          other.remoteSeq == this.remoteSeq &&
          other.anonymous == this.anonymous);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> senderId;
  final Value<String> kind;
  final Value<String?> body;
  final Value<String?> tagId;
  final Value<double?> lat;
  final Value<double?> lng;
  final Value<double?> accuracyM;
  final Value<double?> altitudeM;
  final Value<double?> headingDeg;
  final Value<bool> locationPending;
  final Value<String?> mediaId;
  final Value<String?> mediaMime;
  final Value<String?> mediaKey;
  final Value<String?> replyToId;
  final Value<DateTime> createdAt;
  final Value<DateTime?> editedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> sendState;
  final Value<int?> remoteSeq;
  final Value<bool> anonymous;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.kind = const Value.absent(),
    this.body = const Value.absent(),
    this.tagId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.accuracyM = const Value.absent(),
    this.altitudeM = const Value.absent(),
    this.headingDeg = const Value.absent(),
    this.locationPending = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.mediaMime = const Value.absent(),
    this.mediaKey = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.editedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.sendState = const Value.absent(),
    this.remoteSeq = const Value.absent(),
    this.anonymous = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String groupId,
    required String senderId,
    required String kind,
    this.body = const Value.absent(),
    this.tagId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.accuracyM = const Value.absent(),
    this.altitudeM = const Value.absent(),
    this.headingDeg = const Value.absent(),
    this.locationPending = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.mediaMime = const Value.absent(),
    this.mediaKey = const Value.absent(),
    this.replyToId = const Value.absent(),
    required DateTime createdAt,
    this.editedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.sendState = const Value.absent(),
    this.remoteSeq = const Value.absent(),
    this.anonymous = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       senderId = Value(senderId),
       kind = Value(kind),
       createdAt = Value(createdAt);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? senderId,
    Expression<String>? kind,
    Expression<String>? body,
    Expression<String>? tagId,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<double>? accuracyM,
    Expression<double>? altitudeM,
    Expression<double>? headingDeg,
    Expression<bool>? locationPending,
    Expression<String>? mediaId,
    Expression<String>? mediaMime,
    Expression<String>? mediaKey,
    Expression<String>? replyToId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? editedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? sendState,
    Expression<int>? remoteSeq,
    Expression<bool>? anonymous,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (senderId != null) 'sender_id': senderId,
      if (kind != null) 'kind': kind,
      if (body != null) 'body': body,
      if (tagId != null) 'tag_id': tagId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (altitudeM != null) 'altitude_m': altitudeM,
      if (headingDeg != null) 'heading_deg': headingDeg,
      if (locationPending != null) 'location_pending': locationPending,
      if (mediaId != null) 'media_id': mediaId,
      if (mediaMime != null) 'media_mime': mediaMime,
      if (mediaKey != null) 'media_key': mediaKey,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (createdAt != null) 'created_at': createdAt,
      if (editedAt != null) 'edited_at': editedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (sendState != null) 'send_state': sendState,
      if (remoteSeq != null) 'remote_seq': remoteSeq,
      if (anonymous != null) 'anonymous': anonymous,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? senderId,
    Value<String>? kind,
    Value<String?>? body,
    Value<String?>? tagId,
    Value<double?>? lat,
    Value<double?>? lng,
    Value<double?>? accuracyM,
    Value<double?>? altitudeM,
    Value<double?>? headingDeg,
    Value<bool>? locationPending,
    Value<String?>? mediaId,
    Value<String?>? mediaMime,
    Value<String?>? mediaKey,
    Value<String?>? replyToId,
    Value<DateTime>? createdAt,
    Value<DateTime?>? editedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? sendState,
    Value<int?>? remoteSeq,
    Value<bool>? anonymous,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      kind: kind ?? this.kind,
      body: body ?? this.body,
      tagId: tagId ?? this.tagId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracyM: accuracyM ?? this.accuracyM,
      altitudeM: altitudeM ?? this.altitudeM,
      headingDeg: headingDeg ?? this.headingDeg,
      locationPending: locationPending ?? this.locationPending,
      mediaId: mediaId ?? this.mediaId,
      mediaMime: mediaMime ?? this.mediaMime,
      mediaKey: mediaKey ?? this.mediaKey,
      replyToId: replyToId ?? this.replyToId,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      sendState: sendState ?? this.sendState,
      remoteSeq: remoteSeq ?? this.remoteSeq,
      anonymous: anonymous ?? this.anonymous,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (accuracyM.present) {
      map['accuracy_m'] = Variable<double>(accuracyM.value);
    }
    if (altitudeM.present) {
      map['altitude_m'] = Variable<double>(altitudeM.value);
    }
    if (headingDeg.present) {
      map['heading_deg'] = Variable<double>(headingDeg.value);
    }
    if (locationPending.present) {
      map['location_pending'] = Variable<bool>(locationPending.value);
    }
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (mediaMime.present) {
      map['media_mime'] = Variable<String>(mediaMime.value);
    }
    if (mediaKey.present) {
      map['media_key'] = Variable<String>(mediaKey.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<String>(replyToId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (editedAt.present) {
      map['edited_at'] = Variable<DateTime>(editedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (sendState.present) {
      map['send_state'] = Variable<String>(sendState.value);
    }
    if (remoteSeq.present) {
      map['remote_seq'] = Variable<int>(remoteSeq.value);
    }
    if (anonymous.present) {
      map['anonymous'] = Variable<bool>(anonymous.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('senderId: $senderId, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('tagId: $tagId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('altitudeM: $altitudeM, ')
          ..write('headingDeg: $headingDeg, ')
          ..write('locationPending: $locationPending, ')
          ..write('mediaId: $mediaId, ')
          ..write('mediaMime: $mediaMime, ')
          ..write('mediaKey: $mediaKey, ')
          ..write('replyToId: $replyToId, ')
          ..write('createdAt: $createdAt, ')
          ..write('editedAt: $editedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('sendState: $sendState, ')
          ..write('remoteSeq: $remoteSeq, ')
          ..write('anonymous: $anonymous, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MediaBlobsTable extends MediaBlobs
    with TableInfo<$MediaBlobsTable, MediaBlob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaBlobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, bytes, mime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_blobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaBlob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaBlob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaBlob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
    );
  }

  @override
  $MediaBlobsTable createAlias(String alias) {
    return $MediaBlobsTable(attachedDatabase, alias);
  }
}

class MediaBlob extends DataClass implements Insertable<MediaBlob> {
  final String id;
  final Uint8List bytes;
  final String mime;
  const MediaBlob({required this.id, required this.bytes, required this.mime});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['bytes'] = Variable<Uint8List>(bytes);
    map['mime'] = Variable<String>(mime);
    return map;
  }

  MediaBlobsCompanion toCompanion(bool nullToAbsent) {
    return MediaBlobsCompanion(
      id: Value(id),
      bytes: Value(bytes),
      mime: Value(mime),
    );
  }

  factory MediaBlob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaBlob(
      id: serializer.fromJson<String>(json['id']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      mime: serializer.fromJson<String>(json['mime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'mime': serializer.toJson<String>(mime),
    };
  }

  MediaBlob copyWith({String? id, Uint8List? bytes, String? mime}) => MediaBlob(
    id: id ?? this.id,
    bytes: bytes ?? this.bytes,
    mime: mime ?? this.mime,
  );
  MediaBlob copyWithCompanion(MediaBlobsCompanion data) {
    return MediaBlob(
      id: data.id.present ? data.id.value : this.id,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      mime: data.mime.present ? data.mime.value : this.mime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaBlob(')
          ..write('id: $id, ')
          ..write('bytes: $bytes, ')
          ..write('mime: $mime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, $driftBlobEquality.hash(bytes), mime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaBlob &&
          other.id == this.id &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.mime == this.mime);
}

class MediaBlobsCompanion extends UpdateCompanion<MediaBlob> {
  final Value<String> id;
  final Value<Uint8List> bytes;
  final Value<String> mime;
  final Value<int> rowid;
  const MediaBlobsCompanion({
    this.id = const Value.absent(),
    this.bytes = const Value.absent(),
    this.mime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaBlobsCompanion.insert({
    required String id,
    required Uint8List bytes,
    required String mime,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bytes = Value(bytes),
       mime = Value(mime);
  static Insertable<MediaBlob> custom({
    Expression<String>? id,
    Expression<Uint8List>? bytes,
    Expression<String>? mime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bytes != null) 'bytes': bytes,
      if (mime != null) 'mime': mime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaBlobsCompanion copyWith({
    Value<String>? id,
    Value<Uint8List>? bytes,
    Value<String>? mime,
    Value<int>? rowid,
  }) {
    return MediaBlobsCompanion(
      id: id ?? this.id,
      bytes: bytes ?? this.bytes,
      mime: mime ?? this.mime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaBlobsCompanion(')
          ..write('id: $id, ')
          ..write('bytes: $bytes, ')
          ..write('mime: $mime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrackPointsTable extends TrackPoints
    with TableInfo<$TrackPointsTable, TrackPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accuracyMMeta = const VerificationMeta(
    'accuracyM',
  );
  @override
  late final GeneratedColumn<double> accuracyM = GeneratedColumn<double>(
    'accuracy_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    lat,
    lng,
    accuracyM,
    recordedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('accuracy_m')) {
      context.handle(
        _accuracyMMeta,
        accuracyM.isAcceptableOrUnknown(data['accuracy_m']!, _accuracyMMeta),
      );
    } else if (isInserting) {
      context.missing(_accuracyMMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackPoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      accuracyM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy_m'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
    );
  }

  @override
  $TrackPointsTable createAlias(String alias) {
    return $TrackPointsTable(attachedDatabase, alias);
  }
}

class TrackPoint extends DataClass implements Insertable<TrackPoint> {
  final int id;
  final String ownerId;
  final double lat;
  final double lng;
  final double accuracyM;
  final DateTime recordedAt;
  const TrackPoint({
    required this.id,
    required this.ownerId,
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    map['accuracy_m'] = Variable<double>(accuracyM);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  TrackPointsCompanion toCompanion(bool nullToAbsent) {
    return TrackPointsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      lat: Value(lat),
      lng: Value(lng),
      accuracyM: Value(accuracyM),
      recordedAt: Value(recordedAt),
    );
  }

  factory TrackPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackPoint(
      id: serializer.fromJson<int>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      accuracyM: serializer.fromJson<double>(json['accuracyM']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'accuracyM': serializer.toJson<double>(accuracyM),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  TrackPoint copyWith({
    int? id,
    String? ownerId,
    double? lat,
    double? lng,
    double? accuracyM,
    DateTime? recordedAt,
  }) => TrackPoint(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    accuracyM: accuracyM ?? this.accuracyM,
    recordedAt: recordedAt ?? this.recordedAt,
  );
  TrackPoint copyWithCompanion(TrackPointsCompanion data) {
    return TrackPoint(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      accuracyM: data.accuracyM.present ? data.accuracyM.value : this.accuracyM,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackPoint(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ownerId, lat, lng, accuracyM, recordedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackPoint &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.accuracyM == this.accuracyM &&
          other.recordedAt == this.recordedAt);
}

class TrackPointsCompanion extends UpdateCompanion<TrackPoint> {
  final Value<int> id;
  final Value<String> ownerId;
  final Value<double> lat;
  final Value<double> lng;
  final Value<double> accuracyM;
  final Value<DateTime> recordedAt;
  const TrackPointsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.accuracyM = const Value.absent(),
    this.recordedAt = const Value.absent(),
  });
  TrackPointsCompanion.insert({
    this.id = const Value.absent(),
    required String ownerId,
    required double lat,
    required double lng,
    required double accuracyM,
    required DateTime recordedAt,
  }) : ownerId = Value(ownerId),
       lat = Value(lat),
       lng = Value(lng),
       accuracyM = Value(accuracyM),
       recordedAt = Value(recordedAt);
  static Insertable<TrackPoint> custom({
    Expression<int>? id,
    Expression<String>? ownerId,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<double>? accuracyM,
    Expression<DateTime>? recordedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (recordedAt != null) 'recorded_at': recordedAt,
    });
  }

  TrackPointsCompanion copyWith({
    Value<int>? id,
    Value<String>? ownerId,
    Value<double>? lat,
    Value<double>? lng,
    Value<double>? accuracyM,
    Value<DateTime>? recordedAt,
  }) {
    return TrackPointsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracyM: accuracyM ?? this.accuracyM,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (accuracyM.present) {
      map['accuracy_m'] = Variable<double>(accuracyM.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackPointsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    messageId,
    payloadJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String id;
  final String groupId;
  final String messageId;
  final String payloadJson;
  final DateTime createdAt;
  const OutboxData({
    required this.id,
    required this.groupId,
    required this.messageId,
    required this.payloadJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['message_id'] = Variable<String>(messageId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      groupId: Value(groupId),
      messageId: Value(messageId),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'messageId': serializer.toJson<String>(messageId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxData copyWith({
    String? id,
    String? groupId,
    String? messageId,
    String? payloadJson,
    DateTime? createdAt,
  }) => OutboxData(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    messageId: messageId ?? this.messageId,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('messageId: $messageId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, groupId, messageId, payloadJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.messageId == this.messageId &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> messageId;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String id,
    required String groupId,
    required String messageId,
    required String payloadJson,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       messageId = Value(messageId),
       payloadJson = Value(payloadJson);
  static Insertable<OutboxData> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? messageId,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (messageId != null) 'message_id': messageId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? messageId,
    Value<String>? payloadJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      messageId: messageId ?? this.messageId,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('messageId: $messageId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeqMeta = const VerificationMeta(
    'lastSeq',
  );
  @override
  late final GeneratedColumn<int> lastSeq = GeneratedColumn<int>(
    'last_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [groupId, lastSeq];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('last_seq')) {
      context.handle(
        _lastSeqMeta,
        lastSeq.isAcceptableOrUnknown(data['last_seq']!, _lastSeqMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      lastSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seq'],
      )!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String groupId;
  final int lastSeq;
  const SyncCursor({required this.groupId, required this.lastSeq});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['last_seq'] = Variable<int>(lastSeq);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      groupId: Value(groupId),
      lastSeq: Value(lastSeq),
    );
  }

  factory SyncCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      groupId: serializer.fromJson<String>(json['groupId']),
      lastSeq: serializer.fromJson<int>(json['lastSeq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'lastSeq': serializer.toJson<int>(lastSeq),
    };
  }

  SyncCursor copyWith({String? groupId, int? lastSeq}) => SyncCursor(
    groupId: groupId ?? this.groupId,
    lastSeq: lastSeq ?? this.lastSeq,
  );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      lastSeq: data.lastSeq.present ? data.lastSeq.value : this.lastSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('groupId: $groupId, ')
          ..write('lastSeq: $lastSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, lastSeq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.groupId == this.groupId &&
          other.lastSeq == this.lastSeq);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> groupId;
  final Value<int> lastSeq;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.groupId = const Value.absent(),
    this.lastSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String groupId,
    this.lastSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId);
  static Insertable<SyncCursor> custom({
    Expression<String>? groupId,
    Expression<int>? lastSeq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (lastSeq != null) 'last_seq': lastSeq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? groupId,
    Value<int>? lastSeq,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      groupId: groupId ?? this.groupId,
      lastSeq: lastSeq ?? this.lastSeq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (lastSeq.present) {
      map['last_seq'] = Variable<int>(lastSeq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('groupId: $groupId, ')
          ..write('lastSeq: $lastSeq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AdminEventsTable extends AdminEvents
    with TableInfo<$AdminEventsTable, AdminEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AdminEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
    'actor_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorPublicMeta = const VerificationMeta(
    'actorPublic',
  );
  @override
  late final GeneratedColumn<String> actorPublic = GeneratedColumn<String>(
    'actor_public',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectPublicMeta = const VerificationMeta(
    'subjectPublic',
  );
  @override
  late final GeneratedColumn<String> subjectPublic = GeneratedColumn<String>(
    'subject_public',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _signatureMeta = const VerificationMeta(
    'signature',
  );
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
    'signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    seq,
    kind,
    actorId,
    actorPublic,
    subjectId,
    subjectPublic,
    signature,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'admin_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<AdminEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_actorIdMeta);
    }
    if (data.containsKey('actor_public')) {
      context.handle(
        _actorPublicMeta,
        actorPublic.isAcceptableOrUnknown(
          data['actor_public']!,
          _actorPublicMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actorPublicMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('subject_public')) {
      context.handle(
        _subjectPublicMeta,
        subjectPublic.isAcceptableOrUnknown(
          data['subject_public']!,
          _subjectPublicMeta,
        ),
      );
    }
    if (data.containsKey('signature')) {
      context.handle(
        _signatureMeta,
        signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta),
      );
    } else if (isInserting) {
      context.missing(_signatureMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AdminEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AdminEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_id'],
      )!,
      actorPublic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_public'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      subjectPublic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_public'],
      ),
      signature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AdminEventsTable createAlias(String alias) {
    return $AdminEventsTable(attachedDatabase, alias);
  }
}

class AdminEventRow extends DataClass implements Insertable<AdminEventRow> {
  final String id;
  final String groupId;
  final int? seq;
  final String kind;
  final String actorId;
  final String actorPublic;
  final String subjectId;
  final String? subjectPublic;
  final String signature;
  final DateTime createdAt;
  const AdminEventRow({
    required this.id,
    required this.groupId,
    this.seq,
    required this.kind,
    required this.actorId,
    required this.actorPublic,
    required this.subjectId,
    this.subjectPublic,
    required this.signature,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    if (!nullToAbsent || seq != null) {
      map['seq'] = Variable<int>(seq);
    }
    map['kind'] = Variable<String>(kind);
    map['actor_id'] = Variable<String>(actorId);
    map['actor_public'] = Variable<String>(actorPublic);
    map['subject_id'] = Variable<String>(subjectId);
    if (!nullToAbsent || subjectPublic != null) {
      map['subject_public'] = Variable<String>(subjectPublic);
    }
    map['signature'] = Variable<String>(signature);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AdminEventsCompanion toCompanion(bool nullToAbsent) {
    return AdminEventsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      seq: seq == null && nullToAbsent ? const Value.absent() : Value(seq),
      kind: Value(kind),
      actorId: Value(actorId),
      actorPublic: Value(actorPublic),
      subjectId: Value(subjectId),
      subjectPublic: subjectPublic == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectPublic),
      signature: Value(signature),
      createdAt: Value(createdAt),
    );
  }

  factory AdminEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AdminEventRow(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      seq: serializer.fromJson<int?>(json['seq']),
      kind: serializer.fromJson<String>(json['kind']),
      actorId: serializer.fromJson<String>(json['actorId']),
      actorPublic: serializer.fromJson<String>(json['actorPublic']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      subjectPublic: serializer.fromJson<String?>(json['subjectPublic']),
      signature: serializer.fromJson<String>(json['signature']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'seq': serializer.toJson<int?>(seq),
      'kind': serializer.toJson<String>(kind),
      'actorId': serializer.toJson<String>(actorId),
      'actorPublic': serializer.toJson<String>(actorPublic),
      'subjectId': serializer.toJson<String>(subjectId),
      'subjectPublic': serializer.toJson<String?>(subjectPublic),
      'signature': serializer.toJson<String>(signature),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AdminEventRow copyWith({
    String? id,
    String? groupId,
    Value<int?> seq = const Value.absent(),
    String? kind,
    String? actorId,
    String? actorPublic,
    String? subjectId,
    Value<String?> subjectPublic = const Value.absent(),
    String? signature,
    DateTime? createdAt,
  }) => AdminEventRow(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    seq: seq.present ? seq.value : this.seq,
    kind: kind ?? this.kind,
    actorId: actorId ?? this.actorId,
    actorPublic: actorPublic ?? this.actorPublic,
    subjectId: subjectId ?? this.subjectId,
    subjectPublic: subjectPublic.present
        ? subjectPublic.value
        : this.subjectPublic,
    signature: signature ?? this.signature,
    createdAt: createdAt ?? this.createdAt,
  );
  AdminEventRow copyWithCompanion(AdminEventsCompanion data) {
    return AdminEventRow(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      seq: data.seq.present ? data.seq.value : this.seq,
      kind: data.kind.present ? data.kind.value : this.kind,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      actorPublic: data.actorPublic.present
          ? data.actorPublic.value
          : this.actorPublic,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      subjectPublic: data.subjectPublic.present
          ? data.subjectPublic.value
          : this.subjectPublic,
      signature: data.signature.present ? data.signature.value : this.signature,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AdminEventRow(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('seq: $seq, ')
          ..write('kind: $kind, ')
          ..write('actorId: $actorId, ')
          ..write('actorPublic: $actorPublic, ')
          ..write('subjectId: $subjectId, ')
          ..write('subjectPublic: $subjectPublic, ')
          ..write('signature: $signature, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    seq,
    kind,
    actorId,
    actorPublic,
    subjectId,
    subjectPublic,
    signature,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AdminEventRow &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.seq == this.seq &&
          other.kind == this.kind &&
          other.actorId == this.actorId &&
          other.actorPublic == this.actorPublic &&
          other.subjectId == this.subjectId &&
          other.subjectPublic == this.subjectPublic &&
          other.signature == this.signature &&
          other.createdAt == this.createdAt);
}

class AdminEventsCompanion extends UpdateCompanion<AdminEventRow> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<int?> seq;
  final Value<String> kind;
  final Value<String> actorId;
  final Value<String> actorPublic;
  final Value<String> subjectId;
  final Value<String?> subjectPublic;
  final Value<String> signature;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AdminEventsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.seq = const Value.absent(),
    this.kind = const Value.absent(),
    this.actorId = const Value.absent(),
    this.actorPublic = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.subjectPublic = const Value.absent(),
    this.signature = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AdminEventsCompanion.insert({
    required String id,
    required String groupId,
    this.seq = const Value.absent(),
    required String kind,
    required String actorId,
    required String actorPublic,
    required String subjectId,
    this.subjectPublic = const Value.absent(),
    required String signature,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       kind = Value(kind),
       actorId = Value(actorId),
       actorPublic = Value(actorPublic),
       subjectId = Value(subjectId),
       signature = Value(signature);
  static Insertable<AdminEventRow> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<int>? seq,
    Expression<String>? kind,
    Expression<String>? actorId,
    Expression<String>? actorPublic,
    Expression<String>? subjectId,
    Expression<String>? subjectPublic,
    Expression<String>? signature,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (seq != null) 'seq': seq,
      if (kind != null) 'kind': kind,
      if (actorId != null) 'actor_id': actorId,
      if (actorPublic != null) 'actor_public': actorPublic,
      if (subjectId != null) 'subject_id': subjectId,
      if (subjectPublic != null) 'subject_public': subjectPublic,
      if (signature != null) 'signature': signature,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AdminEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<int?>? seq,
    Value<String>? kind,
    Value<String>? actorId,
    Value<String>? actorPublic,
    Value<String>? subjectId,
    Value<String?>? subjectPublic,
    Value<String>? signature,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AdminEventsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      seq: seq ?? this.seq,
      kind: kind ?? this.kind,
      actorId: actorId ?? this.actorId,
      actorPublic: actorPublic ?? this.actorPublic,
      subjectId: subjectId ?? this.subjectId,
      subjectPublic: subjectPublic ?? this.subjectPublic,
      signature: signature ?? this.signature,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (actorPublic.present) {
      map['actor_public'] = Variable<String>(actorPublic.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (subjectPublic.present) {
      map['subject_public'] = Variable<String>(subjectPublic.value);
    }
    if (signature.present) {
      map['signature'] = Variable<String>(signature.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AdminEventsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('seq: $seq, ')
          ..write('kind: $kind, ')
          ..write('actorId: $actorId, ')
          ..write('actorPublic: $actorPublic, ')
          ..write('subjectId: $subjectId, ')
          ..write('subjectPublic: $subjectPublic, ')
          ..write('signature: $signature, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $GroupsTable groups = $GroupsTable(this);
  late final $HotKeysTable hotKeys = $HotKeysTable(this);
  late final $GroupMembersTable groupMembers = $GroupMembersTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $MediaBlobsTable mediaBlobs = $MediaBlobsTable(this);
  late final $TrackPointsTable trackPoints = $TrackPointsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $AdminEventsTable adminEvents = $AdminEventsTable(this);
  late final Index hotKeysGroup = Index(
    'hot_keys_group',
    'CREATE INDEX hot_keys_group ON hot_keys (group_id)',
  );
  late final Index messagesGroupCreated = Index(
    'messages_group_created',
    'CREATE INDEX messages_group_created ON messages (group_id, created_at)',
  );
  late final Index trackOwnerTime = Index(
    'track_owner_time',
    'CREATE INDEX track_owner_time ON track_points (owner_id, recorded_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    profiles,
    groups,
    hotKeys,
    groupMembers,
    messages,
    mediaBlobs,
    trackPoints,
    outbox,
    syncCursors,
    adminEvents,
    hotKeysGroup,
    messagesGroupCreated,
    trackOwnerTime,
  ];
}

typedef $$ProfilesTableCreateCompanionBuilder =
    ProfilesCompanion Function({
      required String id,
      required String phone,
      Value<String?> displayName,
      Value<String?> signingKey,
      Value<String?> agreementKey,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ProfilesTableUpdateCompanionBuilder =
    ProfilesCompanion Function({
      Value<String> id,
      Value<String> phone,
      Value<String?> displayName,
      Value<String?> signingKey,
      Value<String?> agreementKey,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ProfilesTableReferences
    extends BaseReferences<_$LocalDatabase, $ProfilesTable, Profile> {
  $$ProfilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GroupMembersTable, List<GroupMember>>
  _groupMembersRefsTable(_$LocalDatabase db) => MultiTypedResultKey.fromTable(
    db.groupMembers,
    aliasName: 'profiles__id__group_members__profile_id',
  );

  $$GroupMembersTableProcessedTableManager get groupMembersRefs {
    final manager = $$GroupMembersTableTableManager(
      $_db,
      $_db.groupMembers,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_groupMembersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProfilesTableFilterComposer
    extends Composer<_$LocalDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signingKey => $composableBuilder(
    column: $table.signingKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agreementKey => $composableBuilder(
    column: $table.agreementKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> groupMembersRefs(
    Expression<bool> Function($$GroupMembersTableFilterComposer f) f,
  ) {
    final $$GroupMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groupMembers,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupMembersTableFilterComposer(
            $db: $db,
            $table: $db.groupMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$LocalDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signingKey => $composableBuilder(
    column: $table.signingKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agreementKey => $composableBuilder(
    column: $table.agreementKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signingKey => $composableBuilder(
    column: $table.signingKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get agreementKey => $composableBuilder(
    column: $table.agreementKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> groupMembersRefs<T extends Object>(
    Expression<T> Function($$GroupMembersTableAnnotationComposer a) f,
  ) {
    final $$GroupMembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groupMembers,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupMembersTableAnnotationComposer(
            $db: $db,
            $table: $db.groupMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $ProfilesTable,
          Profile,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (Profile, $$ProfilesTableReferences),
          Profile,
          PrefetchHooks Function({bool groupMembersRefs})
        > {
  $$ProfilesTableTableManager(_$LocalDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> signingKey = const Value.absent(),
                Value<String?> agreementKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                phone: phone,
                displayName: displayName,
                signingKey: signingKey,
                agreementKey: agreementKey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String phone,
                Value<String?> displayName = const Value.absent(),
                Value<String?> signingKey = const Value.absent(),
                Value<String?> agreementKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                phone: phone,
                displayName: displayName,
                signingKey: signingKey,
                agreementKey: agreementKey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupMembersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (groupMembersRefs) db.groupMembers],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (groupMembersRefs)
                    await $_getPrefetchedData<
                      Profile,
                      $ProfilesTable,
                      GroupMember
                    >(
                      currentTable: table,
                      referencedTable: $$ProfilesTableReferences
                          ._groupMembersRefsTable(db),
                      managerFromTypedResult: (p0) => $$ProfilesTableReferences(
                        db,
                        table,
                        p0,
                      ).groupMembersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.profileId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $ProfilesTable,
      Profile,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (Profile, $$ProfilesTableReferences),
      Profile,
      PrefetchHooks Function({bool groupMembersRefs})
    >;
typedef $$GroupsTableCreateCompanionBuilder =
    GroupsCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      required String createdBy,
      required String encKey,
      Value<String?> aoiGeoJson,
      Value<bool> isPublic,
      Value<bool> joinApproval,
      Value<String?> adminRootKey,
      Value<bool> allowMemberExport,
      Value<bool> allowMemberPlace,
      Value<bool> allowOutsideArea,
      Value<int?> gpsLimitM,
      Value<bool> allowMemberTags,
      Value<Uint8List?> photo,
      Value<String?> photoBlobId,
      Value<String?> photoKey,
      Value<DateTime> createdAt,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });
typedef $$GroupsTableUpdateCompanionBuilder =
    GroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<String> createdBy,
      Value<String> encKey,
      Value<String?> aoiGeoJson,
      Value<bool> isPublic,
      Value<bool> joinApproval,
      Value<String?> adminRootKey,
      Value<bool> allowMemberExport,
      Value<bool> allowMemberPlace,
      Value<bool> allowOutsideArea,
      Value<int?> gpsLimitM,
      Value<bool> allowMemberTags,
      Value<Uint8List?> photo,
      Value<String?> photoBlobId,
      Value<String?> photoKey,
      Value<DateTime> createdAt,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });

final class $$GroupsTableReferences
    extends BaseReferences<_$LocalDatabase, $GroupsTable, Group> {
  $$GroupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$HotKeysTable, List<HotKey>> _hotKeysRefsTable(
    _$LocalDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.hotKeys,
    aliasName: 'groups__id__hot_keys__group_id',
  );

  $$HotKeysTableProcessedTableManager get hotKeysRefs {
    final manager = $$HotKeysTableTableManager(
      $_db,
      $_db.hotKeys,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_hotKeysRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GroupMembersTable, List<GroupMember>>
  _groupMembersRefsTable(_$LocalDatabase db) => MultiTypedResultKey.fromTable(
    db.groupMembers,
    aliasName: 'groups__id__group_members__group_id',
  );

  $$GroupMembersTableProcessedTableManager get groupMembersRefs {
    final manager = $$GroupMembersTableTableManager(
      $_db,
      $_db.groupMembers,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_groupMembersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MessagesTable, List<Message>> _messagesRefsTable(
    _$LocalDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: 'groups__id__messages__group_id',
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GroupsTableFilterComposer
    extends Composer<_$LocalDatabase, $GroupsTable> {
  $$GroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encKey => $composableBuilder(
    column: $table.encKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aoiGeoJson => $composableBuilder(
    column: $table.aoiGeoJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPublic => $composableBuilder(
    column: $table.isPublic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get joinApproval => $composableBuilder(
    column: $table.joinApproval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get adminRootKey => $composableBuilder(
    column: $table.adminRootKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowMemberExport => $composableBuilder(
    column: $table.allowMemberExport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowMemberPlace => $composableBuilder(
    column: $table.allowMemberPlace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowOutsideArea => $composableBuilder(
    column: $table.allowOutsideArea,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gpsLimitM => $composableBuilder(
    column: $table.gpsLimitM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowMemberTags => $composableBuilder(
    column: $table.allowMemberTags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get photo => $composableBuilder(
    column: $table.photo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoBlobId => $composableBuilder(
    column: $table.photoBlobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoKey => $composableBuilder(
    column: $table.photoKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> hotKeysRefs(
    Expression<bool> Function($$HotKeysTableFilterComposer f) f,
  ) {
    final $$HotKeysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hotKeys,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HotKeysTableFilterComposer(
            $db: $db,
            $table: $db.hotKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> groupMembersRefs(
    Expression<bool> Function($$GroupMembersTableFilterComposer f) f,
  ) {
    final $$GroupMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groupMembers,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupMembersTableFilterComposer(
            $db: $db,
            $table: $db.groupMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GroupsTableOrderingComposer
    extends Composer<_$LocalDatabase, $GroupsTable> {
  $$GroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encKey => $composableBuilder(
    column: $table.encKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aoiGeoJson => $composableBuilder(
    column: $table.aoiGeoJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPublic => $composableBuilder(
    column: $table.isPublic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get joinApproval => $composableBuilder(
    column: $table.joinApproval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get adminRootKey => $composableBuilder(
    column: $table.adminRootKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowMemberExport => $composableBuilder(
    column: $table.allowMemberExport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowMemberPlace => $composableBuilder(
    column: $table.allowMemberPlace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowOutsideArea => $composableBuilder(
    column: $table.allowOutsideArea,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gpsLimitM => $composableBuilder(
    column: $table.gpsLimitM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowMemberTags => $composableBuilder(
    column: $table.allowMemberTags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get photo => $composableBuilder(
    column: $table.photo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoBlobId => $composableBuilder(
    column: $table.photoBlobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoKey => $composableBuilder(
    column: $table.photoKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $GroupsTable> {
  $$GroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get encKey =>
      $composableBuilder(column: $table.encKey, builder: (column) => column);

  GeneratedColumn<String> get aoiGeoJson => $composableBuilder(
    column: $table.aoiGeoJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPublic =>
      $composableBuilder(column: $table.isPublic, builder: (column) => column);

  GeneratedColumn<bool> get joinApproval => $composableBuilder(
    column: $table.joinApproval,
    builder: (column) => column,
  );

  GeneratedColumn<String> get adminRootKey => $composableBuilder(
    column: $table.adminRootKey,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowMemberExport => $composableBuilder(
    column: $table.allowMemberExport,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowMemberPlace => $composableBuilder(
    column: $table.allowMemberPlace,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowOutsideArea => $composableBuilder(
    column: $table.allowOutsideArea,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gpsLimitM =>
      $composableBuilder(column: $table.gpsLimitM, builder: (column) => column);

  GeneratedColumn<bool> get allowMemberTags => $composableBuilder(
    column: $table.allowMemberTags,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get photo =>
      $composableBuilder(column: $table.photo, builder: (column) => column);

  GeneratedColumn<String> get photoBlobId => $composableBuilder(
    column: $table.photoBlobId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoKey =>
      $composableBuilder(column: $table.photoKey, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  Expression<T> hotKeysRefs<T extends Object>(
    Expression<T> Function($$HotKeysTableAnnotationComposer a) f,
  ) {
    final $$HotKeysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hotKeys,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HotKeysTableAnnotationComposer(
            $db: $db,
            $table: $db.hotKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> groupMembersRefs<T extends Object>(
    Expression<T> Function($$GroupMembersTableAnnotationComposer a) f,
  ) {
    final $$GroupMembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groupMembers,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupMembersTableAnnotationComposer(
            $db: $db,
            $table: $db.groupMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GroupsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $GroupsTable,
          Group,
          $$GroupsTableFilterComposer,
          $$GroupsTableOrderingComposer,
          $$GroupsTableAnnotationComposer,
          $$GroupsTableCreateCompanionBuilder,
          $$GroupsTableUpdateCompanionBuilder,
          (Group, $$GroupsTableReferences),
          Group,
          PrefetchHooks Function({
            bool hotKeysRefs,
            bool groupMembersRefs,
            bool messagesRefs,
          })
        > {
  $$GroupsTableTableManager(_$LocalDatabase db, $GroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<String> encKey = const Value.absent(),
                Value<String?> aoiGeoJson = const Value.absent(),
                Value<bool> isPublic = const Value.absent(),
                Value<bool> joinApproval = const Value.absent(),
                Value<String?> adminRootKey = const Value.absent(),
                Value<bool> allowMemberExport = const Value.absent(),
                Value<bool> allowMemberPlace = const Value.absent(),
                Value<bool> allowOutsideArea = const Value.absent(),
                Value<int?> gpsLimitM = const Value.absent(),
                Value<bool> allowMemberTags = const Value.absent(),
                Value<Uint8List?> photo = const Value.absent(),
                Value<String?> photoBlobId = const Value.absent(),
                Value<String?> photoKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion(
                id: id,
                name: name,
                description: description,
                createdBy: createdBy,
                encKey: encKey,
                aoiGeoJson: aoiGeoJson,
                isPublic: isPublic,
                joinApproval: joinApproval,
                adminRootKey: adminRootKey,
                allowMemberExport: allowMemberExport,
                allowMemberPlace: allowMemberPlace,
                allowOutsideArea: allowOutsideArea,
                gpsLimitM: gpsLimitM,
                allowMemberTags: allowMemberTags,
                photo: photo,
                photoBlobId: photoBlobId,
                photoKey: photoKey,
                createdAt: createdAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                required String createdBy,
                required String encKey,
                Value<String?> aoiGeoJson = const Value.absent(),
                Value<bool> isPublic = const Value.absent(),
                Value<bool> joinApproval = const Value.absent(),
                Value<String?> adminRootKey = const Value.absent(),
                Value<bool> allowMemberExport = const Value.absent(),
                Value<bool> allowMemberPlace = const Value.absent(),
                Value<bool> allowOutsideArea = const Value.absent(),
                Value<int?> gpsLimitM = const Value.absent(),
                Value<bool> allowMemberTags = const Value.absent(),
                Value<Uint8List?> photo = const Value.absent(),
                Value<String?> photoBlobId = const Value.absent(),
                Value<String?> photoKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion.insert(
                id: id,
                name: name,
                description: description,
                createdBy: createdBy,
                encKey: encKey,
                aoiGeoJson: aoiGeoJson,
                isPublic: isPublic,
                joinApproval: joinApproval,
                adminRootKey: adminRootKey,
                allowMemberExport: allowMemberExport,
                allowMemberPlace: allowMemberPlace,
                allowOutsideArea: allowOutsideArea,
                gpsLimitM: gpsLimitM,
                allowMemberTags: allowMemberTags,
                photo: photo,
                photoBlobId: photoBlobId,
                photoKey: photoKey,
                createdAt: createdAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GroupsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                hotKeysRefs = false,
                groupMembersRefs = false,
                messagesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (hotKeysRefs) db.hotKeys,
                    if (groupMembersRefs) db.groupMembers,
                    if (messagesRefs) db.messages,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (hotKeysRefs)
                        await $_getPrefetchedData<Group, $GroupsTable, HotKey>(
                          currentTable: table,
                          referencedTable: $$GroupsTableReferences
                              ._hotKeysRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).hotKeysRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (groupMembersRefs)
                        await $_getPrefetchedData<
                          Group,
                          $GroupsTable,
                          GroupMember
                        >(
                          currentTable: table,
                          referencedTable: $$GroupsTableReferences
                              ._groupMembersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).groupMembersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (messagesRefs)
                        await $_getPrefetchedData<Group, $GroupsTable, Message>(
                          currentTable: table,
                          referencedTable: $$GroupsTableReferences
                              ._messagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).messagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $GroupsTable,
      Group,
      $$GroupsTableFilterComposer,
      $$GroupsTableOrderingComposer,
      $$GroupsTableAnnotationComposer,
      $$GroupsTableCreateCompanionBuilder,
      $$GroupsTableUpdateCompanionBuilder,
      (Group, $$GroupsTableReferences),
      Group,
      PrefetchHooks Function({
        bool hotKeysRefs,
        bool groupMembersRefs,
        bool messagesRefs,
      })
    >;
typedef $$HotKeysTableCreateCompanionBuilder =
    HotKeysCompanion Function({
      required String id,
      required String groupId,
      required String label,
      required int colorValue,
      Value<String?> iconName,
      Value<int> position,
      Value<int> rowid,
    });
typedef $$HotKeysTableUpdateCompanionBuilder =
    HotKeysCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<String> label,
      Value<int> colorValue,
      Value<String?> iconName,
      Value<int> position,
      Value<int> rowid,
    });

final class $$HotKeysTableReferences
    extends BaseReferences<_$LocalDatabase, $HotKeysTable, HotKey> {
  $$HotKeysTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GroupsTable _groupIdTable(_$LocalDatabase db) =>
      db.groups.createAlias('hot_keys__group_id__groups__id');

  $$GroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HotKeysTableFilterComposer
    extends Composer<_$LocalDatabase, $HotKeysTable> {
  $$HotKeysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableFilterComposer get groupId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HotKeysTableOrderingComposer
    extends Composer<_$LocalDatabase, $HotKeysTable> {
  $$HotKeysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableOrderingComposer get groupId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HotKeysTableAnnotationComposer
    extends Composer<_$LocalDatabase, $HotKeysTable> {
  $$HotKeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$GroupsTableAnnotationComposer get groupId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HotKeysTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $HotKeysTable,
          HotKey,
          $$HotKeysTableFilterComposer,
          $$HotKeysTableOrderingComposer,
          $$HotKeysTableAnnotationComposer,
          $$HotKeysTableCreateCompanionBuilder,
          $$HotKeysTableUpdateCompanionBuilder,
          (HotKey, $$HotKeysTableReferences),
          HotKey,
          PrefetchHooks Function({bool groupId})
        > {
  $$HotKeysTableTableManager(_$LocalDatabase db, $HotKeysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HotKeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HotKeysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HotKeysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<String?> iconName = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HotKeysCompanion(
                id: id,
                groupId: groupId,
                label: label,
                colorValue: colorValue,
                iconName: iconName,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String label,
                required int colorValue,
                Value<String?> iconName = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HotKeysCompanion.insert(
                id: id,
                groupId: groupId,
                label: label,
                colorValue: colorValue,
                iconName: iconName,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HotKeysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.groupId,
                                referencedTable: $$HotKeysTableReferences
                                    ._groupIdTable(db),
                                referencedColumn: $$HotKeysTableReferences
                                    ._groupIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HotKeysTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $HotKeysTable,
      HotKey,
      $$HotKeysTableFilterComposer,
      $$HotKeysTableOrderingComposer,
      $$HotKeysTableAnnotationComposer,
      $$HotKeysTableCreateCompanionBuilder,
      $$HotKeysTableUpdateCompanionBuilder,
      (HotKey, $$HotKeysTableReferences),
      HotKey,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$GroupMembersTableCreateCompanionBuilder =
    GroupMembersCompanion Function({
      required String groupId,
      required String profileId,
      Value<String> role,
      Value<DateTime> joinedAt,
      Value<int> rowid,
    });
typedef $$GroupMembersTableUpdateCompanionBuilder =
    GroupMembersCompanion Function({
      Value<String> groupId,
      Value<String> profileId,
      Value<String> role,
      Value<DateTime> joinedAt,
      Value<int> rowid,
    });

final class $$GroupMembersTableReferences
    extends BaseReferences<_$LocalDatabase, $GroupMembersTable, GroupMember> {
  $$GroupMembersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GroupsTable _groupIdTable(_$LocalDatabase db) =>
      db.groups.createAlias('group_members__group_id__groups__id');

  $$GroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProfilesTable _profileIdTable(_$LocalDatabase db) =>
      db.profiles.createAlias('group_members__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GroupMembersTableFilterComposer
    extends Composer<_$LocalDatabase, $GroupMembersTable> {
  $$GroupMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableFilterComposer get groupId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableOrderingComposer
    extends Composer<_$LocalDatabase, $GroupMembersTable> {
  $$GroupMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableOrderingComposer get groupId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableAnnotationComposer
    extends Composer<_$LocalDatabase, $GroupMembersTable> {
  $$GroupMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<DateTime> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  $$GroupsTableAnnotationComposer get groupId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $GroupMembersTable,
          GroupMember,
          $$GroupMembersTableFilterComposer,
          $$GroupMembersTableOrderingComposer,
          $$GroupMembersTableAnnotationComposer,
          $$GroupMembersTableCreateCompanionBuilder,
          $$GroupMembersTableUpdateCompanionBuilder,
          (GroupMember, $$GroupMembersTableReferences),
          GroupMember,
          PrefetchHooks Function({bool groupId, bool profileId})
        > {
  $$GroupMembersTableTableManager(_$LocalDatabase db, $GroupMembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> groupId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<DateTime> joinedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersCompanion(
                groupId: groupId,
                profileId: profileId,
                role: role,
                joinedAt: joinedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupId,
                required String profileId,
                Value<String> role = const Value.absent(),
                Value<DateTime> joinedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersCompanion.insert(
                groupId: groupId,
                profileId: profileId,
                role: role,
                joinedAt: joinedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GroupMembersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false, profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.groupId,
                                referencedTable: $$GroupMembersTableReferences
                                    ._groupIdTable(db),
                                referencedColumn: $$GroupMembersTableReferences
                                    ._groupIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $$GroupMembersTableReferences
                                    ._profileIdTable(db),
                                referencedColumn: $$GroupMembersTableReferences
                                    ._profileIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GroupMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $GroupMembersTable,
      GroupMember,
      $$GroupMembersTableFilterComposer,
      $$GroupMembersTableOrderingComposer,
      $$GroupMembersTableAnnotationComposer,
      $$GroupMembersTableCreateCompanionBuilder,
      $$GroupMembersTableUpdateCompanionBuilder,
      (GroupMember, $$GroupMembersTableReferences),
      GroupMember,
      PrefetchHooks Function({bool groupId, bool profileId})
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String groupId,
      required String senderId,
      required String kind,
      Value<String?> body,
      Value<String?> tagId,
      Value<double?> lat,
      Value<double?> lng,
      Value<double?> accuracyM,
      Value<double?> altitudeM,
      Value<double?> headingDeg,
      Value<bool> locationPending,
      Value<String?> mediaId,
      Value<String?> mediaMime,
      Value<String?> mediaKey,
      Value<String?> replyToId,
      required DateTime createdAt,
      Value<DateTime?> editedAt,
      Value<DateTime?> deletedAt,
      Value<String> sendState,
      Value<int?> remoteSeq,
      Value<bool> anonymous,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<String> senderId,
      Value<String> kind,
      Value<String?> body,
      Value<String?> tagId,
      Value<double?> lat,
      Value<double?> lng,
      Value<double?> accuracyM,
      Value<double?> altitudeM,
      Value<double?> headingDeg,
      Value<bool> locationPending,
      Value<String?> mediaId,
      Value<String?> mediaMime,
      Value<String?> mediaKey,
      Value<String?> replyToId,
      Value<DateTime> createdAt,
      Value<DateTime?> editedAt,
      Value<DateTime?> deletedAt,
      Value<String> sendState,
      Value<int?> remoteSeq,
      Value<bool> anonymous,
      Value<int> rowid,
    });

final class $$MessagesTableReferences
    extends BaseReferences<_$LocalDatabase, $MessagesTable, Message> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GroupsTable _groupIdTable(_$LocalDatabase db) =>
      db.groups.createAlias('messages__group_id__groups__id');

  $$GroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$LocalDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accuracyM => $composableBuilder(
    column: $table.accuracyM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get altitudeM => $composableBuilder(
    column: $table.altitudeM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get headingDeg => $composableBuilder(
    column: $table.headingDeg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get locationPending => $composableBuilder(
    column: $table.locationPending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaMime => $composableBuilder(
    column: $table.mediaMime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaKey => $composableBuilder(
    column: $table.mediaKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get editedAt => $composableBuilder(
    column: $table.editedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sendState => $composableBuilder(
    column: $table.sendState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteSeq => $composableBuilder(
    column: $table.remoteSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get anonymous => $composableBuilder(
    column: $table.anonymous,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableFilterComposer get groupId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$LocalDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accuracyM => $composableBuilder(
    column: $table.accuracyM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get altitudeM => $composableBuilder(
    column: $table.altitudeM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get headingDeg => $composableBuilder(
    column: $table.headingDeg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get locationPending => $composableBuilder(
    column: $table.locationPending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaMime => $composableBuilder(
    column: $table.mediaMime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaKey => $composableBuilder(
    column: $table.mediaKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get editedAt => $composableBuilder(
    column: $table.editedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sendState => $composableBuilder(
    column: $table.sendState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteSeq => $composableBuilder(
    column: $table.remoteSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get anonymous => $composableBuilder(
    column: $table.anonymous,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableOrderingComposer get groupId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<double> get accuracyM =>
      $composableBuilder(column: $table.accuracyM, builder: (column) => column);

  GeneratedColumn<double> get altitudeM =>
      $composableBuilder(column: $table.altitudeM, builder: (column) => column);

  GeneratedColumn<double> get headingDeg => $composableBuilder(
    column: $table.headingDeg,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get locationPending => $composableBuilder(
    column: $table.locationPending,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<String> get mediaMime =>
      $composableBuilder(column: $table.mediaMime, builder: (column) => column);

  GeneratedColumn<String> get mediaKey =>
      $composableBuilder(column: $table.mediaKey, builder: (column) => column);

  GeneratedColumn<String> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get editedAt =>
      $composableBuilder(column: $table.editedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get sendState =>
      $composableBuilder(column: $table.sendState, builder: (column) => column);

  GeneratedColumn<int> get remoteSeq =>
      $composableBuilder(column: $table.remoteSeq, builder: (column) => column);

  GeneratedColumn<bool> get anonymous =>
      $composableBuilder(column: $table.anonymous, builder: (column) => column);

  $$GroupsTableAnnotationComposer get groupId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, $$MessagesTableReferences),
          Message,
          PrefetchHooks Function({bool groupId})
        > {
  $$MessagesTableTableManager(_$LocalDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> tagId = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<double?> accuracyM = const Value.absent(),
                Value<double?> altitudeM = const Value.absent(),
                Value<double?> headingDeg = const Value.absent(),
                Value<bool> locationPending = const Value.absent(),
                Value<String?> mediaId = const Value.absent(),
                Value<String?> mediaMime = const Value.absent(),
                Value<String?> mediaKey = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> editedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> sendState = const Value.absent(),
                Value<int?> remoteSeq = const Value.absent(),
                Value<bool> anonymous = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                groupId: groupId,
                senderId: senderId,
                kind: kind,
                body: body,
                tagId: tagId,
                lat: lat,
                lng: lng,
                accuracyM: accuracyM,
                altitudeM: altitudeM,
                headingDeg: headingDeg,
                locationPending: locationPending,
                mediaId: mediaId,
                mediaMime: mediaMime,
                mediaKey: mediaKey,
                replyToId: replyToId,
                createdAt: createdAt,
                editedAt: editedAt,
                deletedAt: deletedAt,
                sendState: sendState,
                remoteSeq: remoteSeq,
                anonymous: anonymous,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String senderId,
                required String kind,
                Value<String?> body = const Value.absent(),
                Value<String?> tagId = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<double?> accuracyM = const Value.absent(),
                Value<double?> altitudeM = const Value.absent(),
                Value<double?> headingDeg = const Value.absent(),
                Value<bool> locationPending = const Value.absent(),
                Value<String?> mediaId = const Value.absent(),
                Value<String?> mediaMime = const Value.absent(),
                Value<String?> mediaKey = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> editedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> sendState = const Value.absent(),
                Value<int?> remoteSeq = const Value.absent(),
                Value<bool> anonymous = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                groupId: groupId,
                senderId: senderId,
                kind: kind,
                body: body,
                tagId: tagId,
                lat: lat,
                lng: lng,
                accuracyM: accuracyM,
                altitudeM: altitudeM,
                headingDeg: headingDeg,
                locationPending: locationPending,
                mediaId: mediaId,
                mediaMime: mediaMime,
                mediaKey: mediaKey,
                replyToId: replyToId,
                createdAt: createdAt,
                editedAt: editedAt,
                deletedAt: deletedAt,
                sendState: sendState,
                remoteSeq: remoteSeq,
                anonymous: anonymous,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.groupId,
                                referencedTable: $$MessagesTableReferences
                                    ._groupIdTable(db),
                                referencedColumn: $$MessagesTableReferences
                                    ._groupIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, $$MessagesTableReferences),
      Message,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$MediaBlobsTableCreateCompanionBuilder =
    MediaBlobsCompanion Function({
      required String id,
      required Uint8List bytes,
      required String mime,
      Value<int> rowid,
    });
typedef $$MediaBlobsTableUpdateCompanionBuilder =
    MediaBlobsCompanion Function({
      Value<String> id,
      Value<Uint8List> bytes,
      Value<String> mime,
      Value<int> rowid,
    });

class $$MediaBlobsTableFilterComposer
    extends Composer<_$LocalDatabase, $MediaBlobsTable> {
  $$MediaBlobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MediaBlobsTableOrderingComposer
    extends Composer<_$LocalDatabase, $MediaBlobsTable> {
  $$MediaBlobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaBlobsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $MediaBlobsTable> {
  $$MediaBlobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);
}

class $$MediaBlobsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $MediaBlobsTable,
          MediaBlob,
          $$MediaBlobsTableFilterComposer,
          $$MediaBlobsTableOrderingComposer,
          $$MediaBlobsTableAnnotationComposer,
          $$MediaBlobsTableCreateCompanionBuilder,
          $$MediaBlobsTableUpdateCompanionBuilder,
          (
            MediaBlob,
            BaseReferences<_$LocalDatabase, $MediaBlobsTable, MediaBlob>,
          ),
          MediaBlob,
          PrefetchHooks Function()
        > {
  $$MediaBlobsTableTableManager(_$LocalDatabase db, $MediaBlobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaBlobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaBlobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaBlobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaBlobsCompanion(
                id: id,
                bytes: bytes,
                mime: mime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required Uint8List bytes,
                required String mime,
                Value<int> rowid = const Value.absent(),
              }) => MediaBlobsCompanion.insert(
                id: id,
                bytes: bytes,
                mime: mime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MediaBlobsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $MediaBlobsTable,
      MediaBlob,
      $$MediaBlobsTableFilterComposer,
      $$MediaBlobsTableOrderingComposer,
      $$MediaBlobsTableAnnotationComposer,
      $$MediaBlobsTableCreateCompanionBuilder,
      $$MediaBlobsTableUpdateCompanionBuilder,
      (MediaBlob, BaseReferences<_$LocalDatabase, $MediaBlobsTable, MediaBlob>),
      MediaBlob,
      PrefetchHooks Function()
    >;
typedef $$TrackPointsTableCreateCompanionBuilder =
    TrackPointsCompanion Function({
      Value<int> id,
      required String ownerId,
      required double lat,
      required double lng,
      required double accuracyM,
      required DateTime recordedAt,
    });
typedef $$TrackPointsTableUpdateCompanionBuilder =
    TrackPointsCompanion Function({
      Value<int> id,
      Value<String> ownerId,
      Value<double> lat,
      Value<double> lng,
      Value<double> accuracyM,
      Value<DateTime> recordedAt,
    });

class $$TrackPointsTableFilterComposer
    extends Composer<_$LocalDatabase, $TrackPointsTable> {
  $$TrackPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accuracyM => $composableBuilder(
    column: $table.accuracyM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrackPointsTableOrderingComposer
    extends Composer<_$LocalDatabase, $TrackPointsTable> {
  $$TrackPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accuracyM => $composableBuilder(
    column: $table.accuracyM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrackPointsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $TrackPointsTable> {
  $$TrackPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<double> get accuracyM =>
      $composableBuilder(column: $table.accuracyM, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );
}

class $$TrackPointsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $TrackPointsTable,
          TrackPoint,
          $$TrackPointsTableFilterComposer,
          $$TrackPointsTableOrderingComposer,
          $$TrackPointsTableAnnotationComposer,
          $$TrackPointsTableCreateCompanionBuilder,
          $$TrackPointsTableUpdateCompanionBuilder,
          (
            TrackPoint,
            BaseReferences<_$LocalDatabase, $TrackPointsTable, TrackPoint>,
          ),
          TrackPoint,
          PrefetchHooks Function()
        > {
  $$TrackPointsTableTableManager(_$LocalDatabase db, $TrackPointsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<double> accuracyM = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
              }) => TrackPointsCompanion(
                id: id,
                ownerId: ownerId,
                lat: lat,
                lng: lng,
                accuracyM: accuracyM,
                recordedAt: recordedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String ownerId,
                required double lat,
                required double lng,
                required double accuracyM,
                required DateTime recordedAt,
              }) => TrackPointsCompanion.insert(
                id: id,
                ownerId: ownerId,
                lat: lat,
                lng: lng,
                accuracyM: accuracyM,
                recordedAt: recordedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrackPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $TrackPointsTable,
      TrackPoint,
      $$TrackPointsTableFilterComposer,
      $$TrackPointsTableOrderingComposer,
      $$TrackPointsTableAnnotationComposer,
      $$TrackPointsTableCreateCompanionBuilder,
      $$TrackPointsTableUpdateCompanionBuilder,
      (
        TrackPoint,
        BaseReferences<_$LocalDatabase, $TrackPointsTable, TrackPoint>,
      ),
      TrackPoint,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      required String id,
      required String groupId,
      required String messageId,
      required String payloadJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<String> messageId,
      Value<String> payloadJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$LocalDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$LocalDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$LocalDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (
            OutboxData,
            BaseReferences<_$LocalDatabase, $OutboxTable, OutboxData>,
          ),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$LocalDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                groupId: groupId,
                messageId: messageId,
                payloadJson: payloadJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String messageId,
                required String payloadJson,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                groupId: groupId,
                messageId: messageId,
                payloadJson: payloadJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$LocalDatabase, $OutboxTable, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String groupId,
      Value<int> lastSeq,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> groupId,
      Value<int> lastSeq,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$LocalDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeq => $composableBuilder(
    column: $table.lastSeq,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$LocalDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeq => $composableBuilder(
    column: $table.lastSeq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<int> get lastSeq =>
      $composableBuilder(column: $table.lastSeq, builder: (column) => column);
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $SyncCursorsTable,
          SyncCursor,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursor,
            BaseReferences<_$LocalDatabase, $SyncCursorsTable, SyncCursor>,
          ),
          SyncCursor,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(_$LocalDatabase db, $SyncCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> groupId = const Value.absent(),
                Value<int> lastSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                groupId: groupId,
                lastSeq: lastSeq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupId,
                Value<int> lastSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                groupId: groupId,
                lastSeq: lastSeq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $SyncCursorsTable,
      SyncCursor,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursor,
        BaseReferences<_$LocalDatabase, $SyncCursorsTable, SyncCursor>,
      ),
      SyncCursor,
      PrefetchHooks Function()
    >;
typedef $$AdminEventsTableCreateCompanionBuilder =
    AdminEventsCompanion Function({
      required String id,
      required String groupId,
      Value<int?> seq,
      required String kind,
      required String actorId,
      required String actorPublic,
      required String subjectId,
      Value<String?> subjectPublic,
      required String signature,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$AdminEventsTableUpdateCompanionBuilder =
    AdminEventsCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<int?> seq,
      Value<String> kind,
      Value<String> actorId,
      Value<String> actorPublic,
      Value<String> subjectId,
      Value<String?> subjectPublic,
      Value<String> signature,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$AdminEventsTableFilterComposer
    extends Composer<_$LocalDatabase, $AdminEventsTable> {
  $$AdminEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorPublic => $composableBuilder(
    column: $table.actorPublic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectPublic => $composableBuilder(
    column: $table.subjectPublic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AdminEventsTableOrderingComposer
    extends Composer<_$LocalDatabase, $AdminEventsTable> {
  $$AdminEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorPublic => $composableBuilder(
    column: $table.actorPublic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectPublic => $composableBuilder(
    column: $table.subjectPublic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AdminEventsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $AdminEventsTable> {
  $$AdminEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<String> get actorPublic => $composableBuilder(
    column: $table.actorPublic,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get subjectPublic => $composableBuilder(
    column: $table.subjectPublic,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AdminEventsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $AdminEventsTable,
          AdminEventRow,
          $$AdminEventsTableFilterComposer,
          $$AdminEventsTableOrderingComposer,
          $$AdminEventsTableAnnotationComposer,
          $$AdminEventsTableCreateCompanionBuilder,
          $$AdminEventsTableUpdateCompanionBuilder,
          (
            AdminEventRow,
            BaseReferences<_$LocalDatabase, $AdminEventsTable, AdminEventRow>,
          ),
          AdminEventRow,
          PrefetchHooks Function()
        > {
  $$AdminEventsTableTableManager(_$LocalDatabase db, $AdminEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AdminEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AdminEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AdminEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<int?> seq = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> actorId = const Value.absent(),
                Value<String> actorPublic = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String?> subjectPublic = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AdminEventsCompanion(
                id: id,
                groupId: groupId,
                seq: seq,
                kind: kind,
                actorId: actorId,
                actorPublic: actorPublic,
                subjectId: subjectId,
                subjectPublic: subjectPublic,
                signature: signature,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                Value<int?> seq = const Value.absent(),
                required String kind,
                required String actorId,
                required String actorPublic,
                required String subjectId,
                Value<String?> subjectPublic = const Value.absent(),
                required String signature,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AdminEventsCompanion.insert(
                id: id,
                groupId: groupId,
                seq: seq,
                kind: kind,
                actorId: actorId,
                actorPublic: actorPublic,
                subjectId: subjectId,
                subjectPublic: subjectPublic,
                signature: signature,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AdminEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $AdminEventsTable,
      AdminEventRow,
      $$AdminEventsTableFilterComposer,
      $$AdminEventsTableOrderingComposer,
      $$AdminEventsTableAnnotationComposer,
      $$AdminEventsTableCreateCompanionBuilder,
      $$AdminEventsTableUpdateCompanionBuilder,
      (
        AdminEventRow,
        BaseReferences<_$LocalDatabase, $AdminEventsTable, AdminEventRow>,
      ),
      AdminEventRow,
      PrefetchHooks Function()
    >;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db, _db.groups);
  $$HotKeysTableTableManager get hotKeys =>
      $$HotKeysTableTableManager(_db, _db.hotKeys);
  $$GroupMembersTableTableManager get groupMembers =>
      $$GroupMembersTableTableManager(_db, _db.groupMembers);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$MediaBlobsTableTableManager get mediaBlobs =>
      $$MediaBlobsTableTableManager(_db, _db.mediaBlobs);
  $$TrackPointsTableTableManager get trackPoints =>
      $$TrackPointsTableTableManager(_db, _db.trackPoints);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$AdminEventsTableTableManager get adminEvents =>
      $$AdminEventsTableTableManager(_db, _db.adminEvents);
}
