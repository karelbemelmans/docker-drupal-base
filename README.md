# Docker Drupal Base

This repository builds a Docker container for the Drupal 7 core system.

The purpose of this container is to be used as a base container to build other Drupal sites on top of.

## Thoughts about this container

While installing Drupal modules and the core systemn using RUN commands, this is not the best way to do this. Handling the whole `public` directory as simple a bunch of files to add inside the container would be a lot better, but harder to maintain for local development. 
