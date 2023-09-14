#!/bin/bash

source _dxp_util.sh
source _git_util.sh
source _hotfix_util.sh
source _liferay_common.sh
source _publishing_util.sh
source _release_util.sh

function background_run {
	if [ -n "${LIFERAY_COMMON_DEBUG_ENABLED}" ]
	then
		lc_time_run "${@}"
	else
		lc_time_run "${@}" &
	fi
}

function main {
	BUILD_DIR="${HOME}"/.liferay/release-builder/build
	BUNDLES_DIR="${HOME}"/.liferay/release-builder/dev/projects/bundles
	BUILD_TIMESTAMP=$(date +%s)
	PROJECTS_DIR="${HOME}"/.liferay/release-builder/dev/projects

	ANT_OPTS="-Xmx10G"

	#
	# The id of the hotfix
	#

	LIFERAY_RELEASE_BUILD_ID=1

	#
	# The git tag or branch to check out from the liferay-portal-ee
	#
	LIFERAY_RELEASE_GIT_SHA=7.4.13-u92

	#
	# Either release or fix pack
	#
	LIFERAY_RELEASE_OUTPUT=release

	#
	# Tag name in the liferay-portal-ee repository which contains the hotfix testing SHA-s if you would like to build a test hotfix
	#
	LIFERAY_RELEASE_HOTFIX_TESTING_TAG=

	#
	# Git SHA which would be cherry-picked on LIFERAY_RELEASE_GIT_SHA from the tree of LIFERAY_RELEASE_HOTFIX_TESTING_TAG to build a test hotfix
	#
	LIFERAY_RELEASE_HOTFIX_TESTING_SHA=

	#
	# If this is set, the files will be uploaded to the designated buckets
	#
	LIFERAY_RELEASE_UPLOAD=

	#
	# The name of the GCS bucket where the internal files should be copied
	#
	LIFERAY_RELEASE_GCS_INTERNAL_BUCKET=patcher-storage

	LIFERAY_COMMON_LOG_DIR=${BUILD_DIR}

	background_run clone_repository liferay-binaries-cache-2020
	background_run clone_repository liferay-portal-ee
	lc_time_run clone_repository liferay-release-tool-ee
	wait

	lc_time_run clean_portal_git

	background_run init_gcs
	background_run update_portal_git
	lc_time_run update_release_tool_git
	wait

	lc_time_run pre_compile_setup

	lc_time_run decrement_module_versions

	DXP_VERSION=$(get_dxp_version)

	if [ "${LIFERAY_RELEASE_OUTPUT}" == "release" ]
	then
		lc_time_run add_licensing

		lc_time_run compile_dxp

		lc_time_run obfuscate_licensing

		lc_time_run build_dxp

		lc_time_run prepare_legal_files

		lc_time_run deploy_elasticsearch_sidecar

		lc_time_run cleanup_ignored_dxp_modules

		lc_time_run warm_up_tomcat

		lc_time_run package_bundle

		lc_time_run upload_bundle
	else
		lc_time_run add_hotfix_testing_code

		lc_time_run set_hotfix_name

		lc_time_run add_licensing

		lc_time_run compile_dxp

		lc_time_run obfuscate_licensing

		background_run prepare_release_dir
		lc_time_run build_dxp
		wait

		lc_time_run cleanup_ignored_dxp_modules

		lc_time_run add_portal_patcher_properties_jar

		lc_time_run create_hotfix

		lc_time_run calculate_checksums

		lc_time_run create_documentation

		lc_time_run package_hotfix

		lc_time_run upload_hotfix
	fi

	local end_time=$(date +%s)
	local seconds=$((end_time - BUILD_TIMESTAMP))

	echo ">>> Completed ${LIFERAY_RELEASE_OUTPUT} building process in $(lc_echo_time ${seconds}). $(date)"
}

main