SHELL := /bin/bash

.PHONY: build bld_conf bld_clean bld_run bld_test bld_push \
	deploy dep_env dep_shutdown dep_clean dep_pull dep_run dep_test \
	rollback rb_cond rb_run rb_test \
	help

build:
	${STAGE} "Build"
	@ make bld_conf
	@ make bld_clean
	@ make bld_run
	@ make bld_test
	@ make bld_push

deploy:
	${STAGE} "Deploy"
	@ echo 'The application tag to be deployed is : ' ${tag}
	@ echo 'The IP address of the application is :  ' ${builder_ip}
	@ make dep_env
	@ make dep_shutdown
	@ make dep_clean
	@ make dep_pull
	@ make dep_run
	@ make dep_test

rollback:
	${INFO} "Starting rollback operation"
	@ make rb_cond
	@ make rb_run
	@ make rb_test

bld_conf:
	${INFO} "Preparing configuration file"
	@ rm -fv ./tmpfile;                                                                            \
	git checkout .env;                                                                             \
	ip=$$(cat /vagrant/Vagrantfile |grep jm1|grep private_network|awk '{print $$4}'|sed 's/\"//g'); \
	sed -i 's/localhost/'$$ip'/g' ./nginx/nginx.conf;                                              \
	sed -i 's/ip_int_val/'$$ip'/g' .env;                                                           \
	sed -i 's/ip_ext_val/'$$ip'/g' .env;                                                           \
	sed -i 's/tag_val/'${BUILD_ID}'/g' .env;                                                       \
	echo 'ip='$$ip >> ./tmpfile

bld_clean:
	${INFO} "Deleting old images and containers"
	@ docker images | grep "\\$$alexkonkin/app*" || true;                                                                      \
	if [ $$? -eq 0 ];                                                                                                          \
	@sudo docker-compose down || true
	@sudo docker stop $$(sudo docker ps -aq)
	then docker images | grep alexkonkin/app | tr -s ' ' | cut -d ' ' -f 2 | xargs -I {} docker rmi --force alexkonkin/app:{}; \
	else echo "alexkonkin/app images are absent";                                                                              \
	fi
	@ docker images | grep "\\$$app*" || true;                                                                                 \
	if [ $$? -eq 0 ];                                                                                                          \
	then docker images | grep app | tr -s ' ' | cut -d ' ' -f 2 | xargs -I {} docker rmi --force app:{};                       \
	else echo "app images are absent";                                                                                         \
	fi

bld_run:
	${INFO} "Starting the application containers"
	@sudo docker-compose up -d

dep_env:
	${INFO} "Environment file setup to download a desired image from DeockerHub"
	@ git checkout .env
	@ sed -i 's/ip_int_val/'${builder_ip}'/g' .env
	@ sed -i 's/ip_ext_val/'${builder_ip}'/g' .env
	@ sed -i 's/tag_val/'${tag}'/g' .env

dep_shutdown:
	${INFO} "Shutting down existing solution"
	@ sudo docker-compose down

dep_clean:
	${INFO} "Clearing environment from unused images"
	@ docker images | grep "\\$$alexkonkin/app*" || true;                                                                      \
	if [ $$? -eq 0 ];                                                                                                          \
	then docker images | grep alexkonkin/app | tr -s ' ' | cut -d ' ' -f 2 | xargs -I {} docker rmi --force alexkonkin/app:{}; \
	else echo "alexkonkin/app images are absent";                                                                              \
	fi
	@ docker images | grep "\\$$app*" || true;                                                                                 \
	if [ $$? -eq 0 ];                                                                                                          \
	then docker images | grep app | tr -s ' ' | cut -d ' ' -f 2 | xargs -I {} docker rmi --force app:{};                       \
	else echo "app images are absent";                                                                                         \
	fi
	@ if [ $$(docker ps -aq | wc -l) -gt 0 ];                                                                                  \
	then sudo docker rm --force $$(sudo docker ps -aq);                                                                                \
	fi

dep_pull:
	${INFO} "Downloading images from DockerHub"
	@ sudo docker pull alexkonkin/app:${tag}
	@ sudo docker pull alexkonkin/nginx:latest

dep_run:
	${INFO} "Starting solution"
	@ sudo docker-compose up -d

rb_cond:
	${INFO} "Getting information about the current version and the tags available in docker registry"
	versions=($$( wget -q https://registry.hub.docker.com/v1/repositories/alexkonkin/app/tags -O -  | sed -e 's/[][]//g' -e 's/\"//g' -e 's/ //g' | tr '}' '\n'  | awk -F: '{print $$3}'));\
	current_version=$$(docker ps|grep alexkonkin/app|awk '{print $$2}'|awk -F: '{print $$2}');                                                                                             \
	echo "Current version is : "$$current_version;                                                                                                                                         \
	echo "Rollback tag id is : "$$rollback_tag_id;                                                                                                                                         \
	rm -fv ./tmpfile;                                                                                                                                                                      \
	if [[ $${versions[@]} =~ $${current_version} && $${rollback_tag_id} -lt $${current_version} ]];                                                                                        \
	then echo 'rb_cond=true' >> ./tmpfile;                                                                                                                                                 \
	echo 'current_version='$$current_version >> ./tmpfile;                                                                                                                                 \
	echo 'Rollback is possible';                                                                                                                                                           \
	else echo 'rb_cond=false' >> ./tmpfile;echo 'Rollback is not possible';                                                                                                                \
	fi

rb_get_tags:
	${INFO} "Information about the tags available in Docker registry"
	versions=($$( wget -q https://registry.hub.docker.com/v1/repositories/alexkonkin/app/tags -O -  | sed -e 's/[][]//g' -e 's/\"//g' -e 's/ //g' | tr '}' '\n'  | awk -F: '{print $$3}'));\
	echo $${versions[*]}

rb_run:
	${INFO} "Starting rollback"
	@ git checkout .env
	@ . ./tmpfile;                                                                                 \
	if [ $$rb_cond == true ];                                                                      \
	then echo 'Rollback has been started';                                                         \
	ip=$$(cat /vagrant/Vagrantfile |grep js|grep private_network|awk '{print $$4}'|sed 's/\"//g'); \
	sed -i 's/ip_int_val/'$$ip'/g' .env;                                                           \
	sed -i 's/ip_ext_val/'$$ip'/g' .env;                                                           \
	sed -i 's/tag_val/'$$current_version'/g' .env;                                                 \
	echo 'Stopping the version with the tag '$$current_version;                                    \
	sudo docker-compose down;                                                                      \
	for i in $$(sudo docker ps -aq);                                                               \
	do sudo docker stop $$i;                                                                       \
	done;                                                                                          \
	sed -i 's/='$$current_version'/='${rollback_tag_id}'/g' .env;                                  \
	sudo docker pull alexkonkin/app:${rollback_tag_id};                                            \
	sudo docker-compose up -d;                                                                     \
	fi

bld_test:
	${STAGE} "Test"
	@ . ./tmpfile &&                                  \
	curl $$ip | grep Home &&                          \
	echo $$?;                                         \
	if [ $$? -eq 0 ];                                 \
	then echo 'test_step=true' >> ./tmpfile; exit 0;  \
	else echo 'test_step=false' >> ./tmpfile; exit 1; \
	fi

dep_test:
	${STAGE} "Post deployment test"
	@ echo ${builder_ip}
	@ curl ${builder_ip} | grep Home &&               \
	if [ $$? -eq 0 ];                                 \
	then exit 0;                                      \
	else exit 1;                                      \
	fi

rb_test:
	${STAGE} "Post rollback tests"
	${INFO} "Availability of the page"
	@ source ./.env;                                                                                             \
	curl $$IP_EXT | grep Home;
	${INFO} "Comparison of deployed version with the tag passed to rollback operation"
	@ deployed_version=$$(sudo docker ps|grep alexkonkin/app|awk '{print $$2}'|awk -F: '{print $$2}');           \
	if [ $$deployed_version == ${rollback_tag_id} ];                                                             \
	then echo 'The version that has been deployed is equal to the version that was passed to rollback operation';\
	echo 'Deployed versioin is '$$deployed_version;                                                              \
	echo 'The version passed to rollback operation is '${rollback_tag_id};                                       \
	exit 0;                                                                                                      \
	else exit 1;                                                                                                 \
	fi

bld_push: login
	${STAGE} "Pushing images to DockerHub"
	@ . ./.env;                                   \
	. ./tmpfile;                                  \
	if [ $$test_step == true ];                   \
	then docker push alexkonkin/app:$$TAG;        \
	docker push alexkonkin/nginx:latest;          \
	fi
	@ make logout

login:
	${INFO} "Logging in to Docker registry ..."
	@ docker login -u ${USER_CREDENTIALS_USR} -p ${USER_CREDENTIALS_PSW} 2>/dev/null; \
	if [  $$? -eq 0 ];                                                                    \
	then echo 'Logged in to Docker registry'; exit 0;                                     \
	else echo 'Error during login to Docker registry'; exit 1;                            \
	fi

logout:
	${INFO} "Logging out of Docker registry..."
	@ docker logout 2>/dev/null 1>/dev/null &&                                  \
	if [  $$? -eq 0 ];                                                          \
	then echo 'Logged out from Docker registry'; exit 0;                        \
	else echo 'Error during login to Docker registry'; exit 1;                  \
	fi

help:
	@ echo
	@ echo 'build - build the solution, to run please execute export BUILD_ID=<id> && make build'
	@ echo
	@ echo 'deploy - deploy the soulution , to run please execute export tag=<tag> && export builder_ip=<ip> && make deploy'
	@ echo
	@ echo 'rollback - rollback the solution, to run please execute export rollback_tag_id=<ip> && make rollback'
	@ echo
	@ echo 'rb_get_tags - the targed gets all tags from the docker registry, to run execute make rb_get_tags'
	@ echo

# Cosmetics
YELLOW := "\e[1;33m"
NC := "\e[0m"

# Shell Functions
STAGE := @bash -c '\
  printf $(YELLOW); \
  echo "------======< $$1 >======------"; \
  printf $(NC)' SOME_VALUE

INFO := @bash -c '\
  printf $(YELLOW); \
  echo "=> $$1 "; \
  printf $(NC)' SOME_VALUE


