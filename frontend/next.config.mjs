/** @type {import('next').NextConfig} */
const nextConfig = {
  // Remove standalone output mode as we're using a different approach
  experimental: {
    serverComponentsExternalPackages: ['tailwindcss']
  },
  // Set the port to 3001 to match the docker-compose configuration
  serverRuntimeConfig: {
    port: 3001
  },
  // Ensure Next.js knows it's being served at the root path
  basePath: ''
};

export default nextConfig;
