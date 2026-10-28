// Compatibility entry for the desktop dependency bootstrap.
process.argv[2]='desktop';
await import('../../../Shared/Tooling/prepare-dependencies.mjs');
