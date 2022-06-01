public static native func Cast(a: ResRef) -> FxResource;

public native class InWorldNavigation extends IScriptable {
  public static native func GetInstance() -> ref<InWorldNavigation>;

  public let mmcc: ref<MinimapContainerController>;
  public let player: ref<GameObject>;
  let spacing: Float;
  let distanceToPath: Float;
  let closestPoint: Float;
  let interpolationDistance: Float;
  
  let navPathQuestFX: array<ref<FxInstance>>;
  let navPathPOIFX: array<ref<FxInstance>>;
  let navPathYellowResource: FxResource;
  let navPathBlueResource: FxResource;
  let navPathWhiteResource: FxResource;
  let navPathTealResource: FxResource;
  let FXPoints: Int32;

  let questMappin: ref<QuestMappin>;
  let poiMappin: ref<IMappin>;
  let questResource: FxResource;
  let poiResource: FxResource;

  let questVariant: gamedataMappinVariant;
  let poiVariant: gamedataMappinVariant;

  let navPathQuestFXTransforms: array<WorldTransform>;
  let navPathPOIFXTransforms: array<WorldTransform>;

  public func Setup(player: ref<GameObject>) -> Void {
    this.player = player;
    this.spacing = 2.5; // meters
    this.distanceToPath = 50.0; // meters
    this.closestPoint = 1.0; // meters
    this.interpolationDistance = 50.0; // meters
    this.FXPoints = 200;
    this.navPathYellowResource = Cast<FxResource>(r"user\\jackhumbert\\effects\\world_navigation_yellow.effect");
    this.navPathBlueResource = Cast<FxResource>(r"user\\jackhumbert\\effects\\world_navigation_blue.effect");
    this.navPathWhiteResource = Cast<FxResource>(r"user\\jackhumbert\\effects\\world_navigation_white.effect");
    this.navPathTealResource = Cast<FxResource>(r"user\\jackhumbert\\effects\\world_navigation_teal.effect");
  }

  public func GetResourceForVariant(variant: gamedataMappinVariant) -> FxResource {
      switch (variant) {     
        case gamedataMappinVariant.Zzz02_MotorcycleForPurchaseVariant:
        case gamedataMappinVariant.Zzz01_CarForPurchaseVariant:
        case gamedataMappinVariant.Zzz05_ApartmentToPurchaseVariant:
        case gamedataMappinVariant.QuestGiverVariant:
        case gamedataMappinVariant.FixerVariant:
         return this.navPathTealResource;
          break;
        case gamedataMappinVariant.DefaultQuestVariant:
        case gamedataMappinVariant.ExclamationMarkVariant:
          return this.navPathYellowResource; 
          break;
        case gamedataMappinVariant.TarotVariant:
        case gamedataMappinVariant.FastTravelVariant:
          return this.navPathBlueResource;
          break; 
        case gamedataMappinVariant.ServicePointDropPointVariant:
        case gamedataMappinVariant.CustomPositionVariant:
          return this.navPathWhiteResource;
          break;
      }
      return this.navPathWhiteResource;
  }

  public func Update(questOrPOI: Int32) {
    if IsDefined(this.mmcc) {
      if questOrPOI == 0 {
        let questMappin = this.mmcc.GetQuestMappin();
        if IsDefined(questMappin) {
          let questVariant = questMappin.GetVariant();
          if !Equals(questVariant, this.questVariant) {
            this.questVariant = questVariant;
            this.UpdateNavPath(this.navPathQuestFX, this.mmcc.questPoints, this.GetResourceForVariant(this.questVariant), true);
          } else {
            this.UpdateNavPath(this.navPathQuestFX, this.mmcc.questPoints, this.GetResourceForVariant(this.questVariant), false);
          }
        }
      } else {
        let poiMappin = this.mmcc.GetPOIMappin();
        if IsDefined(poiMappin) {
          let poiVariant = poiMappin.GetVariant();
          if !Equals(poiVariant, this.poiVariant) {
            this.poiVariant = poiVariant;
            this.UpdateNavPath(this.navPathPOIFX, this.mmcc.poiPoints, this.GetResourceForVariant(this.poiVariant), true);
          } else {
            this.UpdateNavPath(this.navPathPOIFX, this.mmcc.poiPoints, this.GetResourceForVariant(this.poiVariant), false);
          }
        }
      }
    }
  }

  public func Stop() {
    for fx in this.navPathQuestFX {
      fx.BreakLoop();
    }
    for fx in this.navPathPOIFX {
      fx.BreakLoop();
    }
  }
  private func UpdateNavPath(out fxs:array<ref<FxInstance>>, points: array<Vector4>, resource: FxResource, force: Bool) -> Void {
    // let lastPoint: Vector4 = new Vector4(0.0, 0.0, 0.0, 0.0);
    let lastPoint: Vector4 = points[0];
    let lastFxPoint: Vector4 = points[0];
    let pointsDrawn = 0;
    let skipFirst = false;

    for point in points {
      let tweenPointDistance = Vector4.Distance(point, lastPoint);
      // let correctedPoint = this.AdjustPointToDirection(point, this.distanceToPath);
      if (tweenPointDistance > this.spacing) {
        let rounded = Cast<Float>(RoundF(tweenPointDistance / this.spacing));
        let tweenPointSpacing = this.spacing + (tweenPointDistance - rounded * this.spacing) / rounded;
        let x = 0.0;
        while (x < tweenPointDistance) {
          let midPoint = point / tweenPointDistance * x + lastPoint / tweenPointDistance * (tweenPointDistance - x);      
          // let correctedMidPoint = this.AdjustPointToDirection(midPoint, this.distanceToPath);
          if skipFirst {
            this.UpdateNavPath(fxs, pointsDrawn, midPoint, Quaternion.BuildFromDirectionVector(midPoint - lastFxPoint), resource, force);
            pointsDrawn += 1;
            if (pointsDrawn >= this.FXPoints)
            {
              break;
            }
          } else {
            skipFirst = true;
          }
          lastFxPoint = midPoint;
          x += tweenPointSpacing;
        }
        if (pointsDrawn >= this.FXPoints)
        {
          break;
        }
        lastPoint = point;
      }
    }
    if pointsDrawn < this.FXPoints {
      while pointsDrawn < this.FXPoints {   
        this.UpdateNavPath(fxs, pointsDrawn, new Vector4(0.0, 0.0, -1000.0, 0.0), new Quaternion(0.0, 0.0, 0.0, 1.0), resource, force);
        pointsDrawn += 1;
      }
    }
  }

  private func UpdateNavPath(out fxs: array<ref<FxInstance>>, i: Int32, p: Vector4, q: Quaternion, resource: FxResource, force: Bool) {
    let wT0: WorldTransform;
    WorldTransform.SetPosition(wT0, p);
    WorldTransform.SetOrientation(wT0, q);
    if ArraySize(fxs) < (i + 1) {
      ArrayPush(fxs, GameInstance.GetFxSystem(this.player.GetGame()).SpawnEffectOnGround(resource, wT0));
    } else {
      if !fxs[i].IsValid() || force {
        // fxs[i].BreakLoop();
        fxs[i] = GameInstance.GetFxSystem(this.player.GetGame()).SpawnEffectOnGround(resource, wT0);
      } else {
        fxs[i].UpdateTransform(wT0);
      }
    }
    fxs[i].SetBlackboardValue(n"alpha", MinF(Vector4.Distance2D(this.player.GetWorldPosition(), p) / this.distanceToPath, 1.0));
  }
}