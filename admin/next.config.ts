import { readFileSync } from "node:fs";
import { join } from "node:path";
import type { NextConfig } from "next";

// The app's build number, read from its pubspec as the panel is built, so
// "Force an update" knows which build is the newest without being told.
const pubspec = readFileSync(join(process.cwd(), "..", "app", "pubspec.yaml"), "utf8");
const appBuild = /^version:\s*\S+\+(\d+)\s*$/m.exec(pubspec)?.[1] ?? "0";

// A static site: Firebase Hosting serves it on the free plan, where nothing
// runs on a server. Every page reads Firestore from the browser, as the
// signed-in admin; every change goes through the worker's /admin route.
const nextConfig: NextConfig = {
  output: "export",
  // /users/ is served as users/index.html, which is how Hosting finds it.
  trailingSlash: true,
  images: { unoptimized: true },
  env: { NEXT_PUBLIC_APP_BUILD: appBuild },
};

export default nextConfig;
