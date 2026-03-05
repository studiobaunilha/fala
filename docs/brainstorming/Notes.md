A gente vai planejar algumas melhorias aqui.

Uma coisa para a gente planejar depois que a gente entregar essa V1, começar a planejar para a nossa V2 da aplicação, que seria a gravação de reuniões. Eu preciso ter como consumir o áudio do sistema também. Com isso, eu faço uma transcrição com timestamp do meu microfone e uma transcrição com timestamp do microfone do sistema, e na hora da geração do arquivo eu vou encadeando baseado nos horários, né? E até nas prévias eu tenho que fazer de uma maneira inteligente, a gente pode consultar algum exemplo na internet e entender como é feito, mas para fazer transcrição de reuniões, seria bem útil também essa ferramenta ter essa funcionalidade. E por ser uma aplicação de Mac, a gente poderia bolar uma maneira inteligente de mostrar no Notch (tipo aquele app: Notch Nook).


---

Melhorias/ correções:

No esquema de substituição de texto, um pós-processamento ali, ele deveria ser case insensitive, né? Ou seja, ele encontrou, ele deveria substituir, independente se eu escrever aqui maiúscula, minúscula, tanto faz, ele já é desse jeito?

Sobre aquela parte de acurácia versus velocidade, aquilo ali serve somente para a parte de transcrição de arquivos, correto? Eu acho que isso deveria estar claro ali. Que muitas dessas coisas, na verdade, pelo que eu estou vendo aqui, muitas das coisas que estão aqui no avançado, elas são, na verdade, relacionadas à transcrição de arquivo. Acho que isso deveria ficar claro. Pode gerar uma confusão e a gente achar que está mexendo num parâmetro que serviria também para transcrição de áudio do microfone.

O reconhecimento de múltiplos locutores (diarization) não parece estar funcionando. Eu não sei se é por causa do motor que eu estou usando, ou se isso ocorre como um pós-processamento, pré-processamento, mas num teste que eu fiz aqui não está funcionando.

Se eu selecionar o motor Parakeet eu não precisaria ter nenhum modelo whisper baixado. Hoje eu estou obrigando o usuário a fazer isso. Eu poderia simplesmente deixar nenhum selecionado e excluir todos os modelos, né?

Se o idioma da aplicação estiver selecionado para inglês, a gente deveria tirar do menu a opção traduzir para inglês. Seria redundante, né?

Sobre o pós-processamento, a gente criou um "system prompt" que ele serve para qualquer um dos modos, né? Independente do pós-processamento que está selecionado ali. Eu fiquei pensando que isso está hard-coded no sistema. E a gente deveria deixar isso para o usuário poder modificar, sabe? Que é o prompt de sistema, digamos assim, né? Que dá a atribuição para IA qual que é o objetivo dela, o que ela deve fazer e tudo mais. Eu não vejo por que a gente travar e esconder isso do usuário, sabe?


---

Muitas das coisas que às vezes parecem parar de funcionar quando mexemos em algo, eu gostaria que a gente desse uma olhada melhor, porque deveria ter testes automatizados, né, cara, para garantir que isso não vai acontecer, regressão, end to end, sabe? Pra eu não ter que ficar testando cada vez que a gente faz uma modificação, garantir essas coisas através de testes, né?


----

Sobre as atualizações, eu não acho que elas deveriam estar com uma opção no menu. Eu acredito que elas deveriam estar dentro dos ajustes, lá uma opção de atualizações, onde você marca inclusive atualizações automáticas, verificar se tem atualizações em tempo real e mostra a versão e tudo como geralmente se usa nesse tipo de aplicação.

Ainda dentro da questão dos prompt, eu quero que você me explique como está funcionando. Porque, na verdade, o prompt é formado por mais de uma coisa, né? Vou dar um exemplo: o prompt de desenvolvimento. Ele é formado por um prompt geral de sistema que a gente configura num outro lugar, a lista da stack que a pessoa utiliza para desenvolver e o prompt em si de desenvolvimento. Como que isso é usado dentro da aplicação hoje? Como que é montado esse prompt final para poder fazer o pós-processamento na transcrição?