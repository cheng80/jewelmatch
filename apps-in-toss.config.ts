import { defineConfig } from '@apps-in-toss/web-framework/config';

const appName = process.env.INTOSS_APP_NAME;
if (!appName) {
  throw new Error('INTOSS_APP_NAME is required');
}

export default defineConfig({
  appName,
  brand: {
    primaryColor: '#FF91D5',
  },
  permissions: [],
  navigationBar: {
    withBackButton: false,
    withHomeButton: false,
    withTitle: false,
    transparentBackground: false,
    theme: 'dark',
  },
  webView: {
    bounces: false,
    pullToRefreshEnabled: false,
    overScrollMode: 'never',
    mediaPlaybackRequiresUserAction: false,
  },
  webBundleDir: 'build/web',
});
