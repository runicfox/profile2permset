public with sharing class Profile2PermSet implements Queueable {
    List<ObjectPermissions> profileObjectPerms = new List<SObject>();
    List<FieldPermissions> profileFieldPerms = new List<FieldPermissions>();
    List<ObjectPermissions> permSetObjectPerms = new List<ObjectPermissions>();
    List<FieldPermissions> permSetFieldPerms = new List<FieldPermissions>();
    List<String> profileNames;
    String profileName;
    /**
     * should/could we identify permissions for a "Global"
     * Permission Set?
     */

    public Profile2PermSet() {
        List<Profile> profiles = [SELECT Id, Name FROM Profile];
        profileNames = new List<String>();
        for (Profile profile : profiles) {
            profileNames.add(profile.Name);
        }
        init(profileNames);
    }

    public Profile2PermSet(List<String> profileNames) {
        init(profileNames);
    }

    public void execute(QueueableContext context) {
        createPermSetPermissions();
        profileNames.remove(0);

        if (!profileNames.isEmpty()) {
            System.enqueueJob(new Profile2PermSet(profileNames));
        }
    }

    void init(List<String> profileNames) {
        this.profileNames = profileNames;
        this.profileName = profileNames[0];
        setProfilePermissions();
    }

    void setProfilePermissions() {
        profileObjectPerms = [
            SELECT
                Id,
                ParentId,
                SObjectType,
                Parent.Profile.Name,
                PermissionsEdit,
                PermissionsRead,
                PermissionsDelete,
                PermissionsCreate,
                PermissionsModifyAllRecords,
                PermissionsViewAllRecords
            FROM ObjectPermissions
            WHERE Parent.Profile.Name = :profileName
        ];

        profileFieldPerms = [
            SELECT
                Id,
                ParentId,
                Parent.Profile.Name,
                SObjectType,
                Field,
                PermissionsEdit,
                PermissionsRead
            FROM FieldPermissions
            WHERE Parent.Profile.Name = :profileName
        ];
    }

    void createPermSetPermissions() {
        PermissionSet permission = new PermissionSet(
            Label = profileName,
            Name = getPermissionSetName()
        );
        try {
            insert permission;

            setObjectPerms(permission.Id);
            List<Database.SaveResult> results = Database.insert(
                permSetObjectPerms,
                false
            );

            setFieldPerms(permission.Id);
            insert permSetFieldPerms;
            results.addAll(Database.insert(permSetFieldPerms, false));
            ExceptionHandler.processResults(
                results,
                'Profile2PermSet Field Perms insert'
            );
        } catch (Exception e) {
            ExceptionHandler.process(e, 'Profile2PermSet');
        }
    }

    String getPermissionSetName() {
        Pattern nonAlphanumeric = Pattern.compile('[^a-zA-Z0-9]');
        Matcher matcher = nonAlphanumeric.matcher(profileName);
        String permissionName = matcher.replaceAll('_');

        Pattern multipleUnderscores = Pattern.compile('_{2,}');
        matcher = multipleUnderscores.matcher(permissionName);
        return matcher.replaceAll('');
    }

    void setObjectPerms(Id permissionId) {
        List<SObjectField> fields = new List<SObjectField>{
            ObjectPermissions.SObjectType,
            ObjectPermissions.PermissionsCreate,
            ObjectPermissions.PermissionsRead,
            ObjectPermissions.PermissionsEdit,
            ObjectPermissions.PermissionsDelete,
            ObjectPermissions.PermissionsViewAllRecords,
            ObjectPermissions.PermissionsModifyAllRecords
        };
        for (ObjectPermissions profileObjectPerm : profileObjectPerms) {
            ObjectPermissions permission = new ObjectPermissions(
                ParentId = permissionId
            );
            for (SObjectField field : fields) {
                permission.put(field, profileObjectPerm.get(field));
            }
            permSetObjectPerms.add(permission);
        }
    }

    void setFieldPerms(Id permissionId) {
        List<SObjectField> fields = new List<SObjectField>{
            FieldPermissions.SObjectType,
            FieldPermissions.Field,
            FieldPermissions.PermissionsRead,
            FieldPermissions.PermissionsEdit
        };

        for (FieldPermissions profileFieldPerm : profileFieldPerms) {
            FieldPermissions permission = new FieldPermissions(
                ParentId = permissionId
            );
            for (SObjectField field : fields) {
                permission.put(field, profileFieldPerm.get(field));
            }
            permSetFieldPerms.add(permission);
        }
    }
}
