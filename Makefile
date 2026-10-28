#Dockerfile vars

#vars
TAG=v3.3.2p1-1
ISPCONFIG_TAG=3.3.2p1
IMAGENAME=docker-ispconfig
IMAGEFULLNAME=avhost/${IMAGENAME}
BRANCH=${TAG}
LASTCOMMIT=$(shell git log -1 --pretty=short | tail -n 1 | tr -d " " | tr -d "UPDATE:")
BUILDDATE=$(shell date -u +%Y%m%d)


help:
	    @echo "Makefile arguments:"
	    @echo ""
	    @echo "Makefile commands:"
	    @echo "build"
			@echo "publish-latest"
			@echo "publish-tag"

.DEFAULT_GOAL := all

build:
	@echo ">>>> Build docker image: " ${BRANCH}
	@docker buildx build --progress=plain --load --build-arg ISPCONFIG_TAG=${ISPCONFIG_TAG} --build-arg BUILDDATE=${BUILDDATE} -t ${IMAGEFULLNAME}:${BRANCH} .

push:
	@echo ">>>> Publish docker image: " ${TAG}_${BUILDDATE}
	-docker buildx create --use --name buildkit
	@docker buildx build --push --sbom=true --provenance=true --no-cache=true --build-arg ISPCONFIG_TAG=${ISPCONFIG_TAG} --build-arg BUILDDATE=${BUILDDATE} -t ${IMAGEFULLNAME}:${TAG}_${BUILDDATE} .
	@docker buildx build --push --sbom=true --provenance=true --no-cache=true --build-arg ISPCONFIG_TAG=${ISPCONFIG_TAG} --build-arg BUILDDATE=${BUILDDATE} -t ${IMAGEFULLNAME}:${TAG} .
	@docker buildx build --push --sbom=true --provenance=true --no-cache=true --build-arg ISPCONFIG_TAG=${ISPCONFIG_TAG} --build-arg BUILDDATE=${BUILDDATE} -t ${IMAGEFULLNAME}:${BRANCH} .
	-docker buildx rm buildkit

seccheck:
	grype --add-cpes-if-none dir:.

imagecheck:
	frype --add-cpes-if-none ${IMAGEFULLNAME}:${BRANCH} > cve-report.md

sboom:
	syft dir:. > sbom.txt
	syft dir:. -o json > sbom.json


all: seccheck sboom build imagecheck
