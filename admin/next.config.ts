import type { NextConfig } from "next";

// A static site: Firebase Hosting serves it on the free plan, where nothing
// runs on a server. Every page reads Firestore from the browser, as the
// signed-in admin; every change goes through the worker's /admin route.
const nextConfig: NextConfig = {
  output: "export",
  // /users/ is served as users/index.html, which is how Hosting finds it.
  trailingSlash: true,
  images: { unoptimized: true },
};

export default nextConfig;
