import {
  TossAds,
  loadFullScreenAd,
  showFullScreenAd,
} from '@apps-in-toss/web-framework';

let loadCleanup;
let showCleanup;
let banner;
let bannerInitialized = false;

function cleanupFullScreen() {
  loadCleanup?.();
  showCleanup?.();
  loadCleanup = undefined;
  showCleanup = undefined;
}

window.stoneMatchAds = {
  isRewardedSupported() {
    return (
      loadFullScreenAd.isSupported() && showFullScreenAd.isSupported()
    );
  },

  loadRewarded(adGroupId) {
    loadCleanup?.();
    return new Promise((resolve) => {
      loadCleanup = loadFullScreenAd({
        options: { adGroupId },
        onEvent: (event) => {
          if (event.type === 'loaded') resolve('loaded');
        },
        onError: () => resolve('failed'),
      });
    });
  },

  showRewarded(adGroupId) {
    showCleanup?.();
    let rewarded = false;
    return new Promise((resolve) => {
      const finish = (result) => {
        showCleanup?.();
        showCleanup = undefined;
        resolve(result);
      };
      showCleanup = showFullScreenAd({
        options: { adGroupId },
        onEvent: (event) => {
          if (event.type === 'userEarnedReward') rewarded = true;
          if (event.type === 'dismissed') {
            finish(rewarded ? 'rewarded' : 'dismissed');
          }
          if (event.type === 'failedToShow') finish('failed');
        },
        onError: () => finish('failed'),
      });
    });
  },

  initializeBanner() {
    if (bannerInitialized) return Promise.resolve(true);
    if (
      !TossAds.initialize.isSupported() ||
      !TossAds.attachBanner.isSupported()
    ) {
      return Promise.resolve(false);
    }
    return new Promise((resolve) => {
      TossAds.initialize({
        callbacks: {
          onInitialized: () => {
            bannerInitialized = true;
            resolve(true);
          },
          onInitializationFailed: () => resolve(false),
        },
      });
    });
  },

  showBanner(adGroupId) {
    if (!bannerInitialized || banner) return;
    const target = document.createElement('div');
    target.id = 'stone-match-intoss-banner';
    Object.assign(target.style, {
      position: 'fixed',
      left: '0',
      right: '0',
      bottom: '4px',
      width: '100%',
      height: '96px',
      zIndex: '10000',
    });
    document.body.appendChild(target);
    try {
      banner = TossAds.attachBanner(adGroupId, target, {
        theme: 'dark',
        tone: 'blackAndWhite',
        variant: 'expanded',
      });
    } catch (_) {
      target.remove();
    }
  },

  hideBanner() {
    banner?.destroy();
    banner = undefined;
    document.getElementById('stone-match-intoss-banner')?.remove();
  },

  dispose() {
    cleanupFullScreen();
    this.hideBanner();
  },
};
