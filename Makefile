IP := $(shell cat /vagrant/Vagrantfile |grep jm|grep private_network|awk '{print $$4}'|sed 's/"//g')

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
	@ echo ${tag}
	@ echo ${tag}
	@ echo ${builder_ip}
	${INFO} "Environment file setup to download a desired image from DeockerHub"
	@ sed -i 's/ip_int_val/'${builder_ip}'/g' .env
	@ sed -i 's/ip_ext_val/'${builder_ip}'/g' .env
	@ sed -i 's/tag_val/'${tag}'/g' .env
	
	${INFO} "Shutting down existing solution"
	@ sudo docker-compose down
	@ sudo docker stop $$(sudo docker ps -aq)

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
	
	${INFO} "Downloading images from DockerHub"
	@ sudo docker pull alexkonkin/app:${tag}
	@ sudo docker pull alexkonkin/nginx:latest
	
	${INFO} "Starting solution"
	@ sudo docker-compose up -d

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


