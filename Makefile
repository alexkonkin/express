SHELL := /bin/bash
IP := $(shell cat /vagrant/Vagrantfile |grep jm|grep private_network|awk '{print $$4}'|sed 's/"//g')
versions := ''
current_version := ''

.PHONY: build login logout test push deploy test-deploy

build:
	${STAGE} "Build"
	@ rm -fv ./tmpfile
	@ sed -i 's/localhost/'\$(IP)'/g' ./nginx/nginx.conf
	@ sed -i 's/ip_int_val/'\$(IP)'/g' .env
	@ sed -i 's/ip_ext_val/'\$(IP)'/g' .env
	@ sed -i 's/tag_val/'${BUILD_ID}'/g' .env
	@ echo 'ip='$(IP) >> ./tmpfile
	@ sudo docker-compose down
	@ sudo docker stop $$(sudo docker ps -aq)
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
	@sudo docker-compose up -d
	${INFO} "Build complete"

deploy:
	${STAGE} "Deploy"
	@ echo 'The application tag to be deployed is : ' ${tag}
	@ echo 'The IP address of the application is :  ' ${builder_ip}
	@ make dep_env
	@ make dep_shutdown
	@ make dep_clean
	@ make dep_pull
	@ make dep_start

dep_env:
	${INFO} "Environment file setup to download a desired image from DeockerHub"
	@ sed -i 's/ip_int_val/'${builder_ip}'/g' .env
	@ sed -i 's/ip_ext_val/'${builder_ip}'/g' .env
	@ sed -i 's/tag_val/'${tag}'/g' .env

dep_shutdown:
	${INFO} "Shutting down existing solution"
	@ sudo docker-compose down
	@ sudo docker stop $$(sudo docker ps -aq)

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

dep_pull:
	${INFO} "Downloading images from DockerHub"
	@ sudo docker pull alexkonkin/app:${tag}
	@ sudo docker pull alexkonkin/nginx:latest

dep_start:
	${INFO} "Starting solution"
	@ sudo docker-compose up -d

rollback:
	versions=($$( wget -q https://registry.hub.docker.com/v1/repositories/alexkonkin/app/tags -O -  | sed -e 's/[][]//g' -e 's/\"//g' -e 's/ //g' | tr '}' '\n'  | awk -F: '{print $$3}'));\
	current_version=$$(docker ps|grep alexkonkin/app|awk '{print $$2}'|awk -F: '{print $$2}');\
	echo "Current version is : "$$current_version;\
	echo "Rollback tag id is : "$$rollback_tag_id;\
	if [[ " $${versions[@]} " =~ " $${current_version} " && $${rollback_tag_id} -lt $${current_version} ]]; then echo OK;else echo NOK;fi


test:
	${STAGE} "Test"
	@ . ./tmpfile &&                                  \
	curl $$ip | grep Home &&                          \
	echo $$?;                                         \
	if [ $$? -eq 0 ];                                 \
	then echo 'test_step=true' >> ./tmpfile; exit 0;  \
	else echo 'test_step=false' >> ./tmpfile; exit 1; \
	fi

test-deploy:
	${STAGE} "Post deployment test"
	@ echo ${builder_ip}
	@ curl ${builder_ip} | grep Home &&               \
	if [ $$? -eq 0 ];                                 \
	then exit 0;                                      \
	else exit 1;                                      \
	fi

push: login
	${STAGE} "Pushing images to DockerHub"
	@ . ./.env && \
	docker push alexkonkin/app:$$TAG && \
	docker push alexkonkin/nginx:latest
	@ make logout

login:
	${INFO} "Logging in to Docker registry ..."
	@ docker login -u ${DOCKER_CREDENTIALS_USR} -p ${DOCKER_CREDENTIALS_PSW} 2>/dev/null 1>/dev/null && \
	if [  $$? -eq 0 ];                                                                                  \
	then echo 'Logged in to Docker registry'; exit 0;                                                   \
	else echo 'Error during login to Docker registry'; exit 1;                                          \
	fi

logout:
	${INFO} "Logging out of Docker registry..."
	@ docker logout 2>/dev/null 1>/dev/null &&                                  \
	if [  $$? -eq 0 ];                                                          \
	then echo 'Logged out from Docker registry'; exit 0;                        \
	else echo 'Error during login to Docker registry'; exit 1;                  \
	fi

	
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


