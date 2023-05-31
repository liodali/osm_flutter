class UserTrackingOption {
  final bool initWithUserPosition;
  final bool enableTracking;
  final bool unFollowUser;

  const UserTrackingOption({
    this.enableTracking = false,
    this.unFollowUser = false,
  }) : this.initWithUserPosition = true;

  const UserTrackingOption.withoutUserPosition({
    this.enableTracking = false,
    this.unFollowUser = false,
  }) : this.initWithUserPosition = false;
}
